#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require_relative "lib/cask_bumper"

class DoubaoImeBumper < CaskBumper::Bumper
  DOWNLOAD_API = "https://shurufa.doubao.com/api/v1/app/download_url?platform=macos"
  URL_BUILD_PATTERN = %r{/DoubaoImeInstaller_v(\d+)\.zip\z}
  NESTED_TEMPLATE = "DoubaoImeInstaller_v%<build>s.app/Contents/Resources/DoubaoIme.zip"

  def initialize
    super("doubao-ime")
  end

  private

  def upstream
    @upstream ||= begin
      data = fetch_json(DOWNLOAD_API).fetch("data") { abort "bad API payload" }
      marketing = data["version_name"]&.sub(/\A[Vv]/, "") || abort("missing version_name")
      url = data["url"] || abort("missing url")
      build = url[URL_BUILD_PATTERN, 1] || abort("can't parse build from url: #{url}")
      expected = cask_url_template.sub("\#{version.csv.second}", build)
      abort "upstream URL drifted: got #{url}, expected #{expected}" if url != expected
      { version: "#{marketing},#{build}", build: build, url: url }
    end
  end

  def download_url
    upstream.fetch(:url)
  end

  def validate_download(path)
    nested = format(NESTED_TEMPLATE, build: upstream.fetch(:build))
    listing, status = Open3.capture2e("7z", "l", "-slt", path)
    abort "7z l failed:\n#{listing}" unless status.success?
    target = "Path = #{nested}"
    abort "nested path missing from zip: #{nested}\n#{listing}" unless listing.lines.any? { |l| l.chomp == target }
  end
end

DoubaoImeBumper.new.run if $PROGRAM_NAME == __FILE__
