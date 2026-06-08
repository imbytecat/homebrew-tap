cask "shandianshuo" do
  version "0.6.9"
  sha256 "0b8c8dea4b2a4fc49a41d40b9fb1612b404806888313c130d1bfd97fd377d60b"

  url "https://github.com/shandianshuo/shandianshuo-releases/releases/download/v#{version}/shandianshuo_#{version}_universal.dmg",
      verified: "github.com/shandianshuo/shandianshuo-releases/"
  name "Shandianshuo"
  name "闪电说"
  desc "AI voice input and skill execution assistant"
  homepage "https://shandianshuo.cn/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :big_sur

  app "闪电说.app"

  zap trash: [
    "~/Library/Application Support/cn.shandianshuo.desktop",
    "~/Library/Caches/cn.shandianshuo.desktop",
    "~/Library/HTTPStorages/cn.shandianshuo.desktop",
    "~/Library/Logs/cn.shandianshuo.desktop",
    "~/Library/Preferences/cn.shandianshuo.desktop.plist",
    "~/Library/Saved Application State/cn.shandianshuo.desktop.savedState",
    "~/Library/WebKit/cn.shandianshuo.desktop",
  ]
end
