#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/cask_bumper"

class UgreenNasBumper < CaskBumper::Bumper
  LIST_API = "https://api-zh.ugnas.com/api/system/v3/sa/apk"
  APP_NO = "com.ugreenNasPro.mac"
  ARM_CLIENT_BIT = 3
  EXPECTED_URL_PATTERN =
    %r{\A#{Regexp.escape(CaskBumper::WORKER_BASE)}/ugnas/dl\?v=\#\{version\}&id=\d+\z}
  STRICT_POSITIVE_INT = /\A[1-9]\d*\z/

  def initialize
    super("ugreen-nas")
  end

  private

  def worker_path
    "/ugnas/dl?v=#{upstream.fetch(:version)}&id=#{upstream.fetch(:id)}"
  end

  def cask_url_after_bump
    current = cask_url_template
    abort "UGREEN cask URL shape drift: #{current.inspect}" unless current.match?(EXPECTED_URL_PATTERN)
    current.sub(/\bid=\d+/, "id=#{upstream.fetch(:id)}")
  end

  def upstream
    @upstream ||= begin
      items = fetch_json(LIST_API).dig("data", "appSoftVers") || abort("bad API payload")
      item = items.find { |i| i["appNo"] == APP_NO && i["clientBit"].to_i == ARM_CLIENT_BIT } ||
             abort("no Apple Silicon macOS build found")
      version = item["verName"]&.delete_prefix("v") || abort("missing verName")
      raw_id = item["id"] || abort("missing id")
      id_str = raw_id.to_s
      abort "id is not a strict positive decimal: #{raw_id.inspect}" unless id_str.match?(STRICT_POSITIVE_INT)
      id = id_str.to_i
      { version: version, md5: item["md5"], id: id }
    end
  end
end

UgreenNasBumper.new.run if $PROGRAM_NAME == __FILE__
