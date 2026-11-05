cask "peeksh" do
  version "0.3.3"
  sha256 "7b9788122c2d851baaf28e6f92587731dcde256a3e4f94c2638b7e290dbfd13a"

  url "https://github.com/berkinduz/peeksh/releases/download/v#{version}/Peeksh.dmg"
  name "Peeksh"
  desc "Terminal in your menu bar"
  homepage "https://github.com/berkinduz/peeksh"

  depends_on macos: ">= :ventura"

  app "Peeksh.app"
  binary "#{appdir}/Peeksh.app/Contents/Resources/bin/peeksh"
end
