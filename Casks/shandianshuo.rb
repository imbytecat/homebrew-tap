cask "shandianshuo" do
  version "0.7.1"
  sha256 "7c07f47919800120d6b2aae1879bddbfe1bf67299db4487fd27accfa8abdf940"

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
