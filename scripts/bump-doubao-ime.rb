#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/cask_bumper"

class DoubaoImeBumper < CaskBumper::Bumper
  DOWNLOAD_API = "https://shurufa.doubao.com/api/v1/app/download_url?platform=macos"

  def initialize
    super("doubao-ime")
  end

  private

  def upstream
    @upstream ||= begin
      data = fetch_json(DOWNLOAD_API).fetch("data") { abort "bad API payload" }
      version = data["version_name"]&.delete_prefix("V") || abort("missing version_name")
      url = data["url"] || abort("missing url")
      { version: version, url: url, md5: nil }
    end
  end

  def download_url
    upstream.fetch(:url)
  end
end

DoubaoImeBumper.new.run if $PROGRAM_NAME == __FILE__
