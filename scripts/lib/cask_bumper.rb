# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "tmpdir"
require "uri"

module CaskBumper
  REPO_ROOT = File.expand_path("../..", __dir__).freeze
  WORKER_BASE = "https://homebrew-proxy.imbytecat.workers.dev"

  # Base class for per-cask bumpers. Subclasses override:
  #   * #worker_path   - path on the Worker that 302s to the signed download
  #   * #upstream      - hash with :version and optional :md5 from the LIST endpoint
  class Bumper
    def initialize(name)
      @name = name
      @cask_path = File.join(REPO_ROOT, "Casks/#{name}.rb")
      abort "Cask not found: #{@cask_path}" unless File.file?(@cask_path)
    end

    def run
      info = upstream
      version = info.fetch(:version)
      current = current_cask_version
      if current == version
        warn "[#{@name}] already at #{version}"
        return
      end
      warn "[#{@name}] bump #{current} -> #{version}"

      sha = download_and_sha256(expected_md5: info[:md5])
      rewrite_cask(version: version, sha256: sha)
      warn "[#{@name}] wrote #{@cask_path}"
    end

    private

    def worker_path
      raise NotImplementedError
    end

    def upstream
      raise NotImplementedError
    end

    def download_url
      "#{WORKER_BASE}#{worker_path}"
    end

    def current_cask_version
      File.read(@cask_path)[/^\s*version\s+"([^"]+)"/, 1]
    end

    def download_and_sha256(expected_md5: nil)
      Dir.mktmpdir("#{@name}-bump-") do |tmp|
        dest = File.join(tmp, "download")
        warn "[#{@name}] GET #{download_url}"
        abort "curl failed" unless system("curl", "-fL", "--retry", "3", "-o", dest, download_url)

        if expected_md5
          actual = Digest::MD5.file(dest).hexdigest
          abort "md5 mismatch: got #{actual}, expected #{expected_md5}" if actual != expected_md5
        end

        sha256(dest)
      end
    end

    def sha256(path)
      digest = Digest::SHA256.new
      File.open(path, "rb") { |f| digest << f.read(1 << 16) until f.eof? }
      digest.hexdigest
    end

    def rewrite_cask(version:, sha256:)
      cask = File.read(@cask_path)
      cask.sub!(/^(\s*version\s+)"[^"]+"/, "\\1\"#{version}\"")
      cask.sub!(/^(\s*sha256\s+)"[0-9a-f]{64}"/, "\\1\"#{sha256}\"")
      File.write(@cask_path, cask)
    end

    def fetch_json(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 15
      http.read_timeout = 30
      req = Net::HTTP::Get.new(uri.request_uri)
      req["User-Agent"] = "homebrew-tap-bumper/1.0"
      req["Accept"] = "application/json"
      res = http.request(req)
      abort "HTTP #{res.code} #{url}: #{res.body[0, 200]}" unless res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body)
    end
  end
end
