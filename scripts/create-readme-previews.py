#!/usr/bin/env python3
"""Place genuine captures over generated artwork without changing UI pixels."""
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageCms, ImageDraw, ImageFilter, ImageOps

images = Path(__file__).resolve().parent.parent / 'docs' / 'images'
size = (2048, 1280)
desktop = Image.open(images / 'desktop-scene.png').convert('RGB')
status_icon = Image.open(images / 'menu-bar-status.png').convert('RGBA')
scenes = [
    ('floating-window.jpg', 'terminal-preview.png', 440, 96),
    ('top-drawer.jpg', 'dropdown-preview.png', 20, 88),
]
for capture_name, output_name, left, top in scenes:
    capture_file = Image.open(images / 'captures' / capture_name)
    # Exclude the capture's outer frame and its light corner matte.
    capture = capture_file.convert('RGB').crop((
        8, 8, capture_file.width - 8, capture_file.height - 8,
    ))
    profile = capture_file.info.get('icc_profile')
    background = ImageOps.fit(desktop, size, method=Image.Resampling.LANCZOS)
    icon = status_icon.convert('RGB')
    if profile:
        target_profile = ImageCms.ImageCmsProfile(BytesIO(profile))
        background = ImageCms.profileToProfile(
            background, ImageCms.createProfile('sRGB'),
            target_profile, outputMode='RGB',
        )
        icon = ImageCms.profileToProfile(
            icon, ImageCms.createProfile('sRGB'), target_profile, outputMode='RGB',
        )
    background.paste(icon, (1744, 10), status_icon.getchannel('A'))
    scale = 4
    mask = Image.new('L', (capture.width * scale, capture.height * scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, mask.width - 1, mask.height - 1), radius=20 * scale, fill=255,
    )
    mask = mask.resize(capture.size, Image.Resampling.LANCZOS)
    shadow_mask = Image.new('L', size, 0)
    shadow_mask.paste(mask.point(lambda value: round(value * 0.42)), (left, top + 16))
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(24))
    background.paste((0, 0, 0), (0, 0, *size), shadow_mask)
    # A direct paste at native dimensions preserves every interior RGB sample.
    background.paste(capture, (left, top), mask)
    background.save(images / output_name, format='PNG', icc_profile=profile, optimize=True)
    print(images / output_name)
