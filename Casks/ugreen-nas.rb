cask "ugreen-nas" do
  version "1.16.0.77937"
  sha256 "d6941639a6aac14848bcb8ed93da7eb2686b826bced58d1a63959f51575d34ce"

  url "https://homebrew-proxy.imbytecat.workers.dev/ugnas/dl?v=#{version}&id=536",
      verified: "homebrew-proxy.imbytecat.workers.dev/"
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
  depends_on macos: :big_sur
  depends_on arch:  :arm64

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
