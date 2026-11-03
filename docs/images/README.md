# Product images

The complete macOS desktop scene was created with the built-in imagegen tool in edit mode, using the supplied desktop reference. It includes the menu bar, system icons, clock, and wallpaper. The term-cut status icon is rendered from the application's production BrandMark.

Application windows are genuine CUA captures of term-cut v0.2.1 with Kanagawa Dragon and SF Mono at 14 pt. Application text, controls, tabs, source code, and test results come from the running application.

- `desktop-scene.png`: generated macOS desktop scene.
- `menu-bar-status.png`: application status icon.
- `captures/floating-window.jpg`: original 720 × 560 pt Floating Window capture.
- `captures/top-drawer.jpg`: original Top Drawer capture with a 60% width preference.
- `terminal-preview.png` and `dropdown-preview.png`: compositions used in the main README.
- `demo/storefront/`: runnable cart module and four Node.js tests shown in the terminal.

The compositions retain native screenshot dimensions and original ICC profiles. Eight pixels of decorative frame are cropped from each edge, then an antialiased rounded mask excludes the original corner matte. Interior application pixels are copied directly. Only the desktop and status icon are color-managed; an external shadow is added. Outputs are opaque PNGs.

Run `python3 scripts/create-readme-previews.py` to reproduce the compositions with Pillow. The optional `scripts/show-readme-code.py` source viewer uses Pygments and Kanagawa colors. These image-authoring dependencies are not needed to build the application or DMG. Run `node --test --test-reporter=spec` inside `demo/storefront` to execute the displayed tests.

## Desktop generation prompt

Mode: edit. Reference: user-supplied macOS desktop screenshot. Transparent background: false.

Edit the supplied macOS desktop reference into a clean DESKTOP PLATE for a terminal application product screenshot. This is a complete macOS desktop simulation, not merely wallpaper. Remove the entire large notes application window and its shadow; reconstruct the blue-purple-green flowing macOS wallpaper seamlessly underneath it, continuing the exact same style and colors. Keep the top macOS MENU BAR across the full width, with the Apple logo, Finder, File, Edit, View, Go, Window, Help, the Wi-Fi and Control Center icons and the time 9:41, preserving their positions, native appearance and legible text. The highlighted small notes-app status icon near the upper right should become an EMPTY dark rounded highlight of the same size: remove its white symbol, leave the empty highlight, and keep the other system icons. The real term-cut icon will be inserted there later. No windows or applications anywhere in the desktop area. No writing or logos on the wallpaper. Do not add a monitor, device, desk, white border, white margins, blank white corners or a dock. Edge-to-edge 16:10 desktop screenshot composition, matching the provided reference. The application window will be a genuine screenshot composited later, so do NOT draw a replacement terminal.
