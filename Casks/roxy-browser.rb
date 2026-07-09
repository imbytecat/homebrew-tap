cask "roxy-browser" do
  version "3.9.2"
  sha256 "25c9756b02372734b49d8f48848eb12673d774118c8729e33c04c8b122954bed"

  url "https://sgp1.vultrobjects.com/roxybrowseross/public/package/app/macOS/apple/#{version}/RoxyBrowser_apple_#{version}.pkg",
      verified: "sgp1.vultrobjects.com/roxybrowseross/public/package/app/macOS/apple/"
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
  depends_on macos: :monterey
  depends_on arch:  :arm64

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
