# Product images

The desktop wallpaper was generated with the built-in imagegen tool. The application windows are real CUA captures of term-cut v0.2.1, with Kanagawa Dragon and SF Mono at 14 pt. No application text, controls, tabs, or terminal output were generated or repainted.

- `desktop-wallpaper.png`: generated desktop artwork.
- `captures/floating-window.jpg`: original Floating Window capture at 880 × 420 pt.
- `captures/top-drawer.jpg`: original Top Drawer capture with a 60% width preference.
- `terminal-preview.png` and `dropdown-preview.png`: desktop compositions used in the main README.

The compositions keep each capture at its native pixel dimensions, copy its interior RGB samples without modification, retain its original ICC color profile, and clip its existing rounded corners. Only the generated background is resized and color-managed; an external window shadow is added. Outputs are opaque PNGs.

Run `python3 scripts/create-readme-previews.py` from the repository root to reproduce them. The optional image-authoring dependency is Pillow; it is not needed to build the app or DMG. No API key or generation call is needed to recomposite existing assets.

## Wallpaper prompt

Use case: stylized-concept. Asset type: an elegant desktop wallpaper behind real screenshots of a macOS terminal using Kanagawa Dragon. Produce a high resolution 16:10 edge-to-edge opaque image. Strict palette: near-black warm graphite #0D0C0C and #181616, charcoal #282727 and #393836. Only an extremely restrained dark slate-blue undertone inspired by #8BA4B0 and dark sage inspired by #8A9A7B; all accents very desaturated and dark. A single broad smooth sculptural fold sweeps across the lower third, like softly folded matte graphite, with very subtle diffuse grazing light. Quiet, precise, premium, contemporary desktop wallpaper. Large uninterrupted dark negative space across the center and upper half. Tonal and abstract, not a landscape and not a photograph of a desk or screen. Absolutely no orange, amber, copper, tan, brown scenery, cream, white highlights, bright areas, clouds, mountains, neon, devices, frames, borders, white margins, UI, icons, lettering, logos, or watermark. Fill every corner with the same dark graphite atmosphere. Real terminal screenshots will be placed on top later, so do not draw any application.

