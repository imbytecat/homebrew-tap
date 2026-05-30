#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/cask_bumper"

class UgreenNasBumper < CaskBumper::Bumper
  LIST_API = "https://api-zh.ugnas.com/api/system/v3/sa/apk"
  APP_NO = "com.ugreenNasPro.mac"
  ARM_CLIENT_BIT = 3
  APP_ID = 515

  def initialize
    super("ugreen-nas")
  end

  private

  def worker_path
    "/ugnas/dl?id=#{APP_ID}&v=#{upstream.fetch(:version)}"
  end

  def upstream
    @upstream ||= begin
      items = fetch_json(LIST_API).dig("data", "appSoftVers") || abort("bad API payload")
      item = items.find { |i| i["appNo"] == APP_NO && i["clientBit"].to_i == ARM_CLIENT_BIT } ||
             abort("no Apple Silicon macOS build found")
      version = item["verName"]&.delete_prefix("v") || abort("missing verName")
      { version: version, md5: item["md5"] }
    end
  end
end

UgreenNasBumper.new.run if $PROGRAM_NAME == __FILE__
