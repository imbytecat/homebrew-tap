cask "shandianshuo" do
  version "0.7.8"
  sha256 "ad99825e9ec02c277653dfced3db95ea0167afb1244e50fe400fe0689263609e"

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

  depends_on macos: :monterey

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
