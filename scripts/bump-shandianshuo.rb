#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/cask_bumper"

class ShandianshuoBumper < CaskBumper::Bumper
  RELEASES_API = "https://api.github.com/repos/shandianshuo/shandianshuo-releases/releases/latest"

  def initialize
    super("shandianshuo")
  end

  private

  def upstream
    @upstream ||= begin
      data = fetch_json(RELEASES_API)
      tag = data["tag_name"] || abort("missing tag_name")
      version = tag.sub(/\A[Vv]/, "")
      asset_name = "shandianshuo_#{version}_universal.dmg"
      asset = (data["assets"] || []).find { |a| a["name"] == asset_name } ||
              abort("no asset named #{asset_name}")
      url = asset["browser_download_url"] || abort("missing browser_download_url")
      digest = asset["digest"] || abort("missing digest")
      sha256 = digest.sub(/\Asha256:/, "")
      abort "unexpected digest format: #{digest.inspect}" if sha256 == digest
      expected = cask_url_template.gsub("\#{version}", version)
      abort "upstream URL drifted: got #{url}, expected #{expected}" if url != expected
      { version: version, url: url, sha256: sha256 }
    end
  end

  def download_url
    upstream.fetch(:url)
  end

  def validate_download(path)
    expected = upstream.fetch(:sha256)
    actual = Digest::SHA256.file(path).hexdigest
    abort "sha256 mismatch: got #{actual}, expected #{expected}" if actual != expected
  end
end

ShandianshuoBumper.new.run if $PROGRAM_NAME == __FILE__
