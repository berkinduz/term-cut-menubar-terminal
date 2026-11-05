cask "peeksh" do
  version "0.3.3"
  sha256 "5947a7e324a0e481aa5067e37a24c107e9edcf3a2485b768db158588f1da995a"

  url "https://github.com/berkinduz/peeksh/releases/download/v#{version}/Peeksh.dmg"
  name "Peeksh"
  desc "Terminal in your menu bar"
  homepage "https://github.com/berkinduz/peeksh"

  depends_on macos: ">= :ventura"

  app "Peeksh.app"
  binary "#{appdir}/Peeksh.app/Contents/Resources/bin/peeksh"
end
