#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require_relative "lib/cask_bumper"

class DoubaoImeBumper < CaskBumper::Bumper
  DOWNLOAD_API = "https://shurufa.doubao.com/api/v1/app/download_url?platform=macos"
  NESTED_TEMPLATE = "DoubaoImeInstaller_v%<version>s.app/Contents/Resources/DoubaoIme.zip"

  def initialize
    super("doubao-ime")
  end

  private

  def upstream
    @upstream ||= begin
      data = fetch_json(DOWNLOAD_API).fetch("data") { abort "bad API payload" }
      version = data["version_name"]&.sub(/\A[Vv]/, "") || abort("missing version_name")
      url = data["url"] || abort("missing url")
      expected = cask_url_template.sub("\#{version}", version)
      abort "upstream URL drifted: got #{url}, expected #{expected}" if url != expected
      { version: version, url: url }
    end
  end

  def download_url
    upstream.fetch(:url)
  end

  def validate_download(path)
    nested = format(NESTED_TEMPLATE, version: upstream.fetch(:version))
    listing, status = Open3.capture2e("7z", "l", "-ba", path)
    abort "7z l failed:\n#{listing}" unless status.success?
    abort "nested path missing from zip: #{nested}\n#{listing}" unless listing.include?(nested)
  end
end

DoubaoImeBumper.new.run if $PROGRAM_NAME == __FILE__
