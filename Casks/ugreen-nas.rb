cask "ugreen-nas" do
  version "1.20.0.78579"
  sha256 "297d84c0fc21cf3f3d837e917e49b36fe3e088def3ec37694cfc296bb0bbe310"

  url "https://homebrew-proxy.imbytecat.workers.dev/ugnas/dl?v=#{version}&id=628"
  name "UGREEN NAS"
  name "绿联云"
  desc "Desktop client for UGREEN NAS storage devices"
  homepage "https://www.ugnas.com/"

  livecheck do
    url "https://api-zh.ugnas.com/api/system/v3/sa/apk"
    strategy :json do |json|
      json.dig("data", "appSoftVers")
          &.find { |item| item["appNo"] == "com.ugreenNasPro.mac" && item["clientBit"].to_i == 3 }
          &.dig("verName")
          &.delete_prefix("v")
    end
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on :macos

  app "UGREEN NAS.app"

  uninstall quit: "com.ugreen.pro.client"

  zap trash: [
    "~/Library/Application Support/com.ugreen.desktop",
    "~/Library/Application Support/com.ugreen.pro.client",
    "~/Library/Application Support/UGREEN_Nas_Pro",
    "~/Library/Caches/com.ugreen.desktop",
    "~/Library/Caches/com.ugreen.pro.client",
    "~/Library/Caches/com.ugreen.pro.client.helper*",
    "~/Library/Caches/com.ugreen.pro.client.ShipIt",
    "~/Library/HTTPStorages/com.ugreen.desktop",
    "~/Library/HTTPStorages/com.ugreen.pro.client",
    "~/Library/HTTPStorages/com.ugreen.pro.client.binarycookies",
    "~/Library/Logs/com.ugreen.desktop",
    "~/Library/Logs/com.ugreen.pro.client",
    "~/Library/Logs/UGREEN_Nas_Pro",
    "~/Library/Preferences/com.ugreen.desktop.plist",
    "~/Library/Preferences/com.ugreen.pro.client.plist",
    "~/Library/Saved Application State/com.ugreen.desktop.savedState",
    "~/Library/Saved Application State/com.ugreen.pro.client.savedState",
    "~/Library/UGREEN_Nas_Pro",
    "~/Library/WebKit/com.ugreen.desktop",
    "~/Library/WebKit/com.ugreen.pro.client",
  ]
end
