#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "tmpdir"
require "uri"

API_URL = "https://api.ugnas.com/api/system/v3/sa/apk"
ARM_CLIENT_BIT = 3

REPO_ROOT = File.expand_path("..", __dir__).freeze
CASK_PATH = File.join(REPO_ROOT, "Casks/ugreen-nas.rb").freeze

def fetch_json(url)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == "https")
  http.open_timeout = 15
  http.read_timeout = 30
  req = Net::HTTP::Get.new(uri.request_uri)
  req["User-Agent"] = "ugreen-nas-bumper/1.0"
  req["Accept"] = "application/json"
  res = http.request(req)
  abort "HTTP #{res.code} fetching #{url}: #{res.body[0, 200]}" unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
end

def find_arm_item(items)
  items.find { |i| i["appNo"] == "com.ugreenNasPro.mac" && i["clientBit"].to_i == ARM_CLIENT_BIT }
end

def current_cask_version
  File.read(CASK_PATH)[/^\s*version\s+"([^"]+)"/, 1]
end

def sha256(path)
  digest = Digest::SHA256.new
  File.open(path, "rb") { |f| digest << f.read(1 << 16) until f.eof? }
  digest.hexdigest
end

def main
  warn "Fetching #{API_URL} ..."
  items = fetch_json(API_URL).dig("data", "appSoftVers") || abort("Bad API payload")

  item = find_arm_item(items) || abort("No Apple Silicon macOS build found in API response")
  version = item["verName"]&.delete_prefix("v") || abort("Missing verName")

  current = current_cask_version
  if current == version
    warn "Already at #{version}, nothing to bump."
    exit 0
  end
  warn "Bumping #{current} -> #{version}"

  temp_url = fetch_json(item["pkgUrl"]).dig("data", "linkData", "tempUrl") ||
             abort("API returned no tempUrl for pkg")

  arm_sha = Dir.mktmpdir("ugreen-bump-") do |tmp|
    dest = File.join(tmp, "ugreen-nas-arm64.dmg")
    warn "Downloading #{temp_url[0, 100]}..."
    abort "curl failed" unless system("curl", "-fL", "--retry", "3", "-o", dest, temp_url)

    actual_md5 = Digest::MD5.file(dest).hexdigest
    abort "MD5 mismatch: got #{actual_md5}, expected #{item["md5"]}" if item["md5"] && actual_md5 != item["md5"]

    sha256(dest)
  end

  cask = File.read(CASK_PATH)
  cask.sub!(/^(\s*version\s+)"[^"]+"/, "\\1\"#{version}\"")
  cask.sub!(/^(\s*sha256\s+)"[0-9a-f]{64}"/, "\\1\"#{arm_sha}\"")
  File.write(CASK_PATH, cask)
  warn "Updated #{CASK_PATH}: version=#{version} sha256=#{arm_sha}"
end

main if $PROGRAM_NAME == __FILE__
