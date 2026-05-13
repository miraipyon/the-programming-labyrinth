#!/usr/bin/env python3
"""Check that every res:// reference in project text files points to an existing file."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCAN_DIRS = ("autoload", "data", "scenes", "scripts", "tests")
SCAN_FILES = ("project.godot",)
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".godot", ".json", ".cfg", ".md", ".yml", ".yaml"}
RES_RE = re.compile(r"res://[^\s\"'\)\]\}\,]+")
FRAME_SEQUENCE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}


def iter_text_files() -> list[Path]:
    files: list[Path] = []
    for rel in SCAN_FILES:
        path = ROOT / rel
        if path.exists():
            files.append(path)

    for rel_dir in SCAN_DIRS:
        directory = ROOT / rel_dir
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            if path.is_file() and path.suffix in TEXT_SUFFIXES:
                files.append(path)

    return sorted(set(files))


def normalize_ref(raw: str) -> str:
    return raw.rstrip(".;:")


def ref_exists(ref: str) -> bool:
    """Return True when a res:// reference resolves to a file or animation prefix."""

    # Runtime-formatted references such as res://assets/%s/attack.png are
    # validated by data/scenes at runtime; this text scanner cannot expand them.
    if "%" in ref:
        return True

    rel = ref.removeprefix("res://")
    target = ROOT / rel
    if target.exists():
        return True

    # SpriteAnimator stores frame sequences as prefix paths, for example:
    # res://assets/foo/Animation/Idle/idle -> idle1.png, idle2.png, ...
    if target.suffix:
        return False

    parent = target.parent
    prefix = target.name
    if not parent.exists() or not prefix:
        return False

    for candidate in parent.iterdir():
        if not candidate.is_file() or candidate.suffix.lower() not in FRAME_SEQUENCE_SUFFIXES:
            continue
        stem = candidate.stem
        if not stem.startswith(prefix):
            continue
        frame_number = stem[len(prefix):]
        if frame_number.isdigit() and int(frame_number) > 0:
            return True
    return False


def main() -> int:
    checked = 0
    missing: list[tuple[str, int, str]] = []

    for path in iter_text_files():
        text = path.read_text(encoding="utf-8", errors="replace")
        for line_no, line in enumerate(text.splitlines(), start=1):
            for match in RES_RE.finditer(line):
                ref = normalize_ref(match.group(0))
                checked += 1
                if not ref_exists(ref):
                    display = path.relative_to(ROOT).as_posix()
                    missing.append((display, line_no, ref))

    print(f"CHECKED {checked}")
    print(f"MISSING {len(missing)}")
    for file_path, line_no, ref in missing:
        print(f"{file_path}:{line_no}: missing {ref}")

    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
