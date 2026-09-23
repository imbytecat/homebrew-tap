cask "roxy-browser" do
  version "4.0.6"
  sha256 "d9717b09a73cdc9f95fc3642a60521ba8508603c4050a56abef39db4bacd8f74"

  url "https://sgp1.vultrobjects.com/roxybrowseross/private/package/app/macOS/apple/#{version}/RoxyBrowser_apple_#{version}.pkg"
  name "RoxyBrowser"
  name "Roxy浏览器"
  desc "Anti-detect fingerprint browser for multi-account management"
  homepage "https://roxybrowser.cn/"

  livecheck do
    url "https://dl.roxybrowser.com/app-download/macOS-apple-latest"
    regex(%r{/macOS/apple/(\d+(?:\.\d+)+)/RoxyBrowser_apple_}i)
    strategy :header_match
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :monterey

  pkg "RoxyBrowser_apple_#{version}.pkg"

  uninstall quit:    "com.roxybrowser.app",
            pkgutil: "com.roxybrowser.app"

  zap trash: [
    "~/Library/Application Support/com.roxybrowser.app",
    "~/Library/Application Support/RoxyBrowser",
    "~/Library/Caches/com.roxybrowser.app",
    "~/Library/Caches/com.roxybrowser.app.helper*",
    "~/Library/Caches/com.roxybrowser.app.ShipIt",
    "~/Library/HTTPStorages/com.roxybrowser.app",
    "~/Library/HTTPStorages/com.roxybrowser.app.binarycookies",
    "~/Library/Logs/com.roxybrowser.app",
    "~/Library/Logs/RoxyBrowser",
    "~/Library/Preferences/com.roxybrowser.app.plist",
    "~/Library/Saved Application State/com.roxybrowser.app.savedState",
    "~/Library/WebKit/com.roxybrowser.app",
  ]
end
