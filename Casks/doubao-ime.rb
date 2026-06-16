cask "doubao-ime" do
  version "0.9.2"
  sha256 "c561241aaac39fd6036c6eda34ca433d95e75563220ca31017d5b54c295ef37e"

  url "https://lf-wave.doubaocdn.com/obj/doubao-ime/app/mac/DoubaoImeInstaller_v#{version}.zip",
      verified: "lf-wave.doubaocdn.com/obj/doubao-ime/app/mac/"
  name "Doubao IME"
  name "豆包输入法"
  desc "Voice-first input method by ByteDance"
  homepage "https://shurufa.doubao.com/"

  livecheck do
    url "https://shurufa.doubao.com/api/v1/app/download_url?platform=macos"
    strategy :json do |json|
      json.dig("data", "version_name")&.sub(/\A[Vv]/, "")
    end
  end

  depends_on macos: :catalina
  container nested: "DoubaoImeInstaller_v#{version}.app/Contents/Resources/DoubaoIme.zip"

  input_method "DoubaoIme.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-d", "-r", "com.apple.quarantine",
                          "#{Dir.home}/Library/Input Methods/DoubaoIme.app"]
  end

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
