#!/usr/bin/env python3
"""Patch remaining icons_plus source files."""
import os, re, sys

SRC_DIR = r'G:\workspace\anx-reader-develop\packages\icons_plus\lib\src'

FILE_MAP = {
    'boxicons.dart': ('BoxIconData', 'BoxIcons'),
    'evaicons.dart': ('EvaIconData', 'EvaIcons'),
    'heroicons.dart': ('HeroIconData', 'HeroIcons'),
    'ionicons.dart': ('IonIconData', 'IonIcons'),
    'octicons.dart': ('OctIconData', 'OctIcons'),
    'pixelarticons.dart': ('PixelArtIconData', 'PixelartIcons'),
    'teenyicons.dart': ('TeenyIconData', 'TeenyIcons'),
    'zondicons.dart': ('ZondIconData', 'ZondIcons'),
}

for filename, (subclass_name, font_family) in FILE_MAP.items():
    filepath = os.path.join(SRC_DIR, filename)
    if not os.path.exists(filepath):
        print(f"SKIP: {filename} - not found")
        continue

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove class definition
    # The class is small: class Xxx extends IconData { const Xxx(int code): super(code, fontFamily:'...', fontPackage:'...'); }
    pattern = re.compile(
        r'class ' + re.escape(subclass_name) + r' extends IconData \{.*?const ' + re.escape(subclass_name) + r'\(int code\).*?super\(.*?fontPackage.*?icons_plus.*?\).*?;.*?\}',
        re.DOTALL
    )
    if pattern.search(content):
        content = pattern.sub('', content)
        # Replace XxxIconData(code) with IconData(code, fontFamily:'..', fontPackage:'..')
        content = re.sub(
            re.escape(subclass_name) + r'\((\w+)\)',
            lambda m: f"IconData({m.group(1)}, fontFamily: '{font_family}', fontPackage: 'icons_plus')",
            content
        )
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"PATCHED: {filename}")
    else:
        print(f"OK (already patched): {filename}")

print("Done!")
