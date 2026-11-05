cask "peeksh" do
  version "0.3.4"
  sha256 "2dc3f46d68ee1a1ad8683223286a44179a1451040403e4d4da3a6c6048588f54"

  url "https://github.com/berkinduz/peeksh/releases/download/v#{version}/Peeksh.dmg"
  name "Peeksh"
  desc "Terminal in your menu bar"
  homepage "https://github.com/berkinduz/peeksh"

  auto_updates true
  depends_on macos: ">= :ventura"

  app "Peeksh.app"
  binary "#{appdir}/Peeksh.app/Contents/Resources/bin/peeksh"
end
