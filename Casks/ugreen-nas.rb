require "download_strategy"
require "json"

# UGREEN NAS's macOS DMG sits behind a short-lived signed URL that has to be
# fetched from their JSON API first:
#
#   GET https://api-zh.ugnas.com/api/system/v1/ua/temp/link?appType=client&id=515
#   => { "data": { "linkData": { "tempUrl": "https://dl-cn.ugnas.com/.../<file>.dmg?..." } } }
#
# We resolve the signed URL at install time, then defer to the normal curl
# pipeline. Modeled on `CurlApacheMirrorDownloadStrategy`.
class UgreenApiDownloadStrategy < CurlDownloadStrategy
  private

  def resolve_url_basename_time_file_size(url, timeout: nil)
    return super if url != self.url

    super(api_temp_url(timeout:), timeout:)
  end

  def api_temp_url(timeout: nil)
    @api_temp_url ||= begin
      body = curl_output("--silent", "--location", url, timeout:).stdout
      data = JSON.parse(body)
      data.dig("data", "linkData", "tempUrl") ||
        raise(CurlDownloadStrategyError.new(url, "UGREEN API: #{data["msg"] || body[0, 200]}"))
    end
  rescue JSON::ParserError => e
    raise CurlDownloadStrategyError.new(url, "UGREEN API JSON parse failed: #{e.message}")
  end
end

cask "ugreen-nas" do
  version "1.15.0.77685"
  sha256 "56b49d6e516657caaf7c97eb75ab2352bbd7ad962e2c8e01fdea5fdd096f0f62"

  url "https://api-zh.ugnas.com/api/system/v1/ua/temp/link?appType=client&id=515",
      using:    UgreenApiDownloadStrategy,
      verified: "ugnas.com/"
  name "UGREEN NAS"
  name "绿联云"
  desc "Desktop client for UGREEN NAS storage devices"
  homepage "https://www.ugnas.com/"

  livecheck do
    url "https://api.ugnas.com/api/system/v3/sa/apk"
    strategy :json do |json|
      json.dig("data", "appSoftVers")
          &.find { |item| item["appNo"] == "com.ugreenNasPro.mac" && item["clientBit"].to_i == 3 }
          &.dig("verName")
          &.delete_prefix("v")
    end
  end

  auto_updates true
  depends_on macos: :big_sur
  depends_on arch:  :arm64

  app "UGREEN NAS.app"

  uninstall quit: "com.ugreen.pro.client"

  zap trash: [
    "~/Library/Application Support/UGREEN NAS",
    "~/Library/Caches/com.ugreen.pro.client",
    "~/Library/Caches/com.ugreen.pro.client.ShipIt",
    "~/Library/HTTPStorages/com.ugreen.pro.client",
    "~/Library/HTTPStorages/com.ugreen.pro.client.binarycookies",
    "~/Library/Logs/UGREEN NAS",
    "~/Library/Preferences/com.ugreen.pro.client.plist",
    "~/Library/Saved Application State/com.ugreen.pro.client.savedState",
    "~/Library/WebKit/com.ugreen.pro.client",
  ]
end
