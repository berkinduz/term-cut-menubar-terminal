#!/usr/bin/env python3
"""Place genuine captures over generated artwork without changing UI pixels."""
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageCms, ImageDraw, ImageFilter, ImageOps

images = Path(__file__).resolve().parent.parent / 'docs' / 'images'
size = (2048, 1280)
wallpaper = Image.open(images / 'desktop-wallpaper.png').convert('RGB')
scenes = [
    ('floating-window.jpg', 'terminal-preview.png', 208),
    ('top-drawer.jpg', 'dropdown-preview.png', 24),
]
for capture_name, output_name, top in scenes:
    capture_file = Image.open(images / 'captures' / capture_name)
    capture = capture_file.convert('RGB')
    profile = capture_file.info.get('icc_profile')
    background = ImageOps.fit(wallpaper, size, method=Image.Resampling.LANCZOS)
    if profile:
        background = ImageCms.profileToProfile(
            background, ImageCms.createProfile('sRGB'),
            ImageCms.ImageCmsProfile(BytesIO(profile)), outputMode='RGB',
        )
    left = (size[0] - capture.width) // 2
    mask = Image.new('L', capture.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, capture.width - 1, capture.height - 1), radius=28, fill=255,
    )
    shadow_mask = Image.new('L', size, 0)
    shadow_mask.paste(mask.point(lambda value: round(value * 0.42)), (left, top + 16))
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(24))
    background.paste((0, 0, 0), (0, 0, *size), shadow_mask)
    # A direct paste at native dimensions preserves every interior RGB sample.
    background.paste(capture, (left, top), mask)
    background.save(images / output_name, format='PNG', icc_profile=profile, optimize=True)
    print(images / output_name)
