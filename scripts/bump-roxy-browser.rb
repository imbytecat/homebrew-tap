#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require_relative "lib/cask_bumper"

class RoxyBrowserBumper < CaskBumper::Bumper
  VERSION_API = "https://roxybrowser.cn/app_statistics/get_official_website_version_data_config"
  LATEST_URL = "https://dl.roxybrowser.com/app-download/macOS-apple-latest"
  URL_PATTERN = %r{/macOS/apple/([^/]+)/RoxyBrowser_apple_[^/]+\.pkg\z}
  KNOWN_INSTALL_DOMAINS = %w[
    hz.gate.roxybrowser.cn
    sg.gate.roxybrowser.net
    us.gate.roxybrowser.net
  ].freeze

  def initialize
    super("roxy-browser")
  end

  private

  def upstream
    @upstream ||= begin
      data = fetch_json(VERSION_API).fetch("data") { abort "bad version API payload" }
      version = data["macVersion"] || abort("missing macVersion")
      location = fetch_redirect_location(LATEST_URL)
      m = location.match(URL_PATTERN) || abort("can't parse version from Location: #{location}")
      abort "version source disagreement: JSON=#{version}, Location=#{m[1]}" if m[1] != version
      expected = cask_url_template.gsub("\#{version}", version)
      abort "upstream URL drifted: got #{location}, expected #{expected}" if location != expected
      { version: version, url: location }
    end
  end

  def download_url
    upstream.fetch(:url)
  end

  def validate_download(path)
    Dir.mktmpdir("roxy-pkg-audit-") do |tmp|
      expanded = File.join(tmp, "expanded")
      out, status = Open3.capture2e("pkgutil", "--expand-full", path, expanded)
      abort "pkgutil --expand-full failed:\n#{out}" unless status.success?

      Dir.glob(File.join(expanded, "**/Scripts/*")).each do |script|
        next unless File.file?(script)

        content = File.read(script, encoding: "UTF-8", invalid: :replace)
        hosts = content.scan(%r{https?://([a-zA-Z0-9.-]+)}).flatten.uniq
        unknown = hosts.reject { |h| KNOWN_INSTALL_DOMAINS.include?(h) }
        abort "unexpected host in pkg script #{File.basename(script)}: #{unknown.inspect}" unless unknown.empty?
      end
    end
  end
end

RoxyBrowserBumper.new.run if $PROGRAM_NAME == __FILE__
