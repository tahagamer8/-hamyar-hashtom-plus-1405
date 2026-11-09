#!/usr/bin/env python3
"""Apply Fahmino's separate Android identity and branded launcher artwork."""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw

APP_ID = "ir.fahmino.clone.fahminoseparate"
APP_LABEL = "فهمینو"
DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
ROOT = Path(__file__).resolve().parents[1]


def _set_manifest_attribute(xml: str, name: str, value: str) -> str:
    pattern = re.compile(rf'android:{name}="[^"]*"')
    replacement = f'android:{name}="{value}"'
    if pattern.search(xml):
        return pattern.sub(replacement, xml, count=1)
    updated, count = re.subn(
        r"(<application\b)",
        rf'\1 android:{name}="{value}"',
        xml,
        count=1,
    )
    if count != 1:
        raise RuntimeError(f"Could not set Android manifest attribute: {name}")
    return updated


def _set_gradle_setting(text: str, setting: str, value: str) -> str:
    pattern = re.compile(
        rf'(?m)^(\s*{setting}\s*(?:=\s*)?)[\'"][^\'"]+[\'"]'
    )
    updated, count = pattern.subn(
        lambda match: match.group(1) + f'"{value}"',
        text,
        count=1,
    )
    if count != 1:
        raise RuntimeError(f"Could not find Gradle setting: {setting}")
    return updated


def configure_android_branding(root: Path = ROOT) -> None:
    icon_path = root / "assets" / "images" / "fahmino_app_icon.jpg"
    if not icon_path.is_file():
        raise FileNotFoundError(f"Fahmino app icon is missing: {icon_path}")

    app_dir = root / "android" / "app"
    manifest_path = app_dir / "src" / "main" / "AndroidManifest.xml"
    if not manifest_path.is_file():
        raise FileNotFoundError(f"Android manifest is missing: {manifest_path}")

    gradle_path = app_dir / "build.gradle.kts"
    if not gradle_path.is_file():
        gradle_path = app_dir / "build.gradle"
    if not gradle_path.is_file():
        raise FileNotFoundError("Could not find android/app/build.gradle(.kts)")

    gradle = gradle_path.read_text(encoding="utf-8")
    gradle = _set_gradle_setting(gradle, "namespace", APP_ID)
    gradle = _set_gradle_setting(gradle, "applicationId", APP_ID)
    gradle_path.write_text(gradle, encoding="utf-8")

    manifest = manifest_path.read_text(encoding="utf-8")
    manifest = _set_manifest_attribute(manifest, "label", APP_LABEL)
    manifest = _set_manifest_attribute(manifest, "icon", "@mipmap/ic_launcher")
    manifest = _set_manifest_attribute(
        manifest, "roundIcon", "@mipmap/ic_launcher_round"
    )
    manifest_path.write_text(manifest, encoding="utf-8")

    res_dir = app_dir / "src" / "main" / "res"
    source = Image.open(icon_path).convert("RGB")

    for density, size in DENSITIES.items():
        mipmap_dir = res_dir / f"mipmap-{density}"
        mipmap_dir.mkdir(parents=True, exist_ok=True)
        resized = source.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(
            mipmap_dir / "ic_launcher.png", format="PNG", optimize=True
        )

        round_icon = resized.convert("RGBA")
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
        round_icon.putalpha(mask)
        round_icon.save(
            mipmap_dir / "ic_launcher_round.png",
            format="PNG",
            optimize=True,
        )

        foreground_size = int(size * 2.25)
        foreground = source.resize(
            (foreground_size, foreground_size), Image.Resampling.LANCZOS
        )
        foreground.save(
            mipmap_dir / "ic_launcher_foreground.png",
            format="PNG",
            optimize=True,
        )

    adaptive_dir = res_dir / "mipmap-anydpi-v26"
    adaptive_dir.mkdir(parents=True, exist_ok=True)
    adaptive_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
    (adaptive_dir / "ic_launcher.xml").write_text(
        adaptive_xml, encoding="utf-8"
    )
    (adaptive_dir / "ic_launcher_round.xml").write_text(
        adaptive_xml, encoding="utf-8"
    )

    values_dir = res_dir / "values"
    values_dir.mkdir(parents=True, exist_ok=True)
    (values_dir / "ic_launcher_background.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#080D38</color>
</resources>
""",
        encoding="utf-8",
    )

    if APP_ID not in gradle or APP_LABEL not in manifest:
        raise RuntimeError("Fahmino Android identity/label verification failed.")
    required = [
        res_dir / f"mipmap-{density}" / "ic_launcher.png"
        for density in DENSITIES
    ]
    if not all(path.is_file() and path.stat().st_size > 0 for path in required):
        raise RuntimeError("One or more generated launcher icons are missing.")

    print(f"Android applicationId: {APP_ID}")
    print(f"Android label: {APP_LABEL}")
    print("Fahmino launcher icons generated for all Android densities.")


if __name__ == "__main__":
    configure_android_branding()
