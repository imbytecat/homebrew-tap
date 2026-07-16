cask "shandianshuo" do
  version "0.7.5"
  sha256 "9f50ea578e3225981308b2d9b13e6716c518805680eb57c473a148c553299723"

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
