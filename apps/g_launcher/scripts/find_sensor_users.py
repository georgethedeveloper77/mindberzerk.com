#!/usr/bin/env python3
"""Find native code that registers Android sensors, in the app and its plugins.

Dart code only reaches sensors through a plugin, so a clean `grep lib/` does
not rule anything out. This walks every package listed in
`.dart_tool/package_config.json`, plus the app's own `android/` folder, and
prints each Kotlin or Java line that touches the sensor APIs.

Works inside a pub workspace, where package_config.json lives at the
workspace root rather than in the app folder.

Usage (from apps/g_launcher, after `flutter pub get`):
    python3 scripts/find_sensor_users.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

CONFIG_REL = Path(".dart_tool/package_config.json")
SOURCE_SUFFIXES = {".kt", ".java"}
PATTERN = re.compile(
    r"SensorManager|SensorEventListener|registerListener\(|getDefaultSensor"
    r"|OrientationEventListener|TYPE_ROTATION_VECTOR|TYPE_ACCELEROMETER"
)


def find_config() -> Path:
    """Locate package_config.json here or in any parent (pub workspaces)."""
    here = Path.cwd().resolve()
    for folder in (here, *here.parents):
        candidate = folder / CONFIG_REL
        if candidate.is_file():
            return candidate
    sys.exit(f"{CONFIG_REL} not found. Run `flutter pub get` first.")


def package_roots() -> list[tuple[str, Path]]:
    """Return (name, root) for the app and every resolved dependency."""
    config_path = find_config()
    config = json.loads(config_path.read_text())
    roots: list[tuple[str, Path]] = []
    for package in config["packages"]:
        uri = package["rootUri"]
        # rootUri is either an absolute file:// URI (pub cache) or a path
        # relative to the .dart_tool folder (path and workspace packages).
        if uri.startswith("file://"):
            root = Path(unquote(urlparse(uri).path))
        else:
            root = (config_path.parent / uri).resolve()
        roots.append((package["name"], root))
    return roots


def scan(name: str, android_dir: Path) -> int:
    """Print matching lines under one android/ folder. Returns hit count."""
    hits = 0
    for path in sorted(android_dir.rglob("*")):
        if path.suffix not in SOURCE_SUFFIXES or "build" in path.parts:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for number, line in enumerate(text.splitlines(), start=1):
            if PATTERN.search(line):
                rel = path.relative_to(android_dir.parent)
                print(f"{name:<28} {rel}:{number}  {line.strip()[:100]}")
                hits += 1
    return hits


def main() -> None:
    total = 0
    for name, root in package_roots():
        android_dir = root / "android"
        if android_dir.is_dir():
            total += scan(name, android_dir)

    if total == 0:
        print("No native sensor usage found in the app or any plugin.")


if __name__ == "__main__":
    main()
