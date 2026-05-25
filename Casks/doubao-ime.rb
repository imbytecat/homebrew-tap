cask "doubao-ime" do
  version "0.9.0"
  sha256 "b3db587a25deca06964c2d88961ccbb7824f14e58b5347bad5893f7fd9b1a421"

  url "https://lf-wave.doubaocdn.com/obj/doubao-ime/app/mac/DoubaoImeInstaller_v#{version}.zip",
      verified: "lf-wave.doubaocdn.com/obj/doubao-ime/"
  name "Doubao IME"
  name "豆包输入法"
  desc "Voice-first input method by ByteDance"
  homepage "https://shurufa.doubao.com/"

  livecheck do
    url "https://shurufa.doubao.com/api/v1/app/download_url?platform=macos"
    strategy :json do |json|
      json.dig("data", "version_name")&.delete_prefix("V")
    end
  end

  depends_on macos: :catalina
  container nested: "DoubaoImeInstaller_v#{version}.app/Contents/Resources/DoubaoIme.zip"

  input_method "DoubaoIme.app"

  uninstall quit: [
    "com.bytedance.inputmethod.doubaoime",
    "com.bytedance.inputmethod.doubaoime.settings",
  ]

  zap trash: [
    "~/Library/Application Support/com.bytedance.inputmethod.doubaoime",
    "~/Library/Application Support/com.bytedance.inputmethod.doubaoime.settings",
    "~/Library/Caches/com.bytedance.inputmethod.doubaoime",
    "~/Library/Caches/com.bytedance.inputmethod.doubaoime.settings",
    "~/Library/Containers/com.bytedance.inputmethod.doubaoime",
    "~/Library/Containers/com.bytedance.inputmethod.doubaoime.settings",
    "~/Library/HTTPStorages/com.bytedance.inputmethod.doubaoime",
    "~/Library/Logs/com.bytedance.inputmethod.doubaoime",
    "~/Library/Preferences/com.bytedance.inputmethod.doubaoime.plist",
    "~/Library/Preferences/com.bytedance.inputmethod.doubaoime.settings.plist",
    "~/Library/Saved Application State/com.bytedance.inputmethod.doubaoime.savedState",
  ]
end
