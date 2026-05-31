#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/cask_bumper"

class RoxyBrowserBumper < CaskBumper::Bumper
  LATEST_URL = "https://dl.roxybrowser.com/app-download/macOS-apple-latest"
  URL_PATTERN = %r{/macOS/apple/([^/]+)/RoxyBrowser_apple_[^/]+\.pkg\z}

  def initialize
    super("roxy-browser")
  end

  private

  def upstream
    @upstream ||= begin
      location = fetch_redirect_location(LATEST_URL)
      m = location.match(URL_PATTERN) || abort("can't parse version from #{location}")
      version = m[1]
      expected = cask_url_template.gsub("\#{version}", version)
      abort "upstream URL drifted: got #{location}, expected #{expected}" if location != expected
      { version: version, url: location }
    end
  end

  def download_url
    upstream.fetch(:url)
  end
end

RoxyBrowserBumper.new.run if $PROGRAM_NAME == __FILE__
