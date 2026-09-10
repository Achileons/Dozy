#!/usr/bin/env python3
"""Check the app's custom fonts line up.

Three things have to agree for a custom font to load, and when they do not the app fails
silently — iOS just draws the system face instead:

  1. the file is in Dozy/Resources/Fonts,
  2. its file name is listed under UIAppFonts in Dozy/Info.plist,
  3. the PostScript name *inside* the file is the one Typography.swift asks for.

The third is the one that catches people out: the name inside a font is set by whoever
built it and need not match the file name at all. This reads it out of the file and
compares all three.

    python3 Tools/check_fonts.py

Exits non-zero if anything disagrees. Standard library only.
"""

from __future__ import annotations

import plistlib
import re
import struct
import sys
from pathlib import Path

FONT_DIR = Path("Dozy/Resources/Fonts")
INFO_PLIST = Path("Dozy/Info.plist")
TYPOGRAPHY = Path("Dozy/Theme/Typography.swift")

# nameID 6 in the OpenType 'name' table is the PostScript name.
POSTSCRIPT_NAME_ID = 6


def postscript_name(path: Path) -> str | None:
    """The PostScript name recorded inside a TrueType or OpenType file."""
    data = path.read_bytes()
    if len(data) < 12:
        return None

    tag = data[:4]
    if tag == b"ttcf":
        return None  # A collection holds several fonts; not what we ship.

    table_count = struct.unpack(">H", data[4:6])[0]
    name_table = None
    for index in range(table_count):
        entry = 12 + index * 16
        if entry + 16 > len(data):
            return None
        table_tag, _, offset, length = struct.unpack(">4sIII", data[entry:entry + 16])
        if table_tag == b"name":
            name_table = (offset, length)
            break

    if name_table is None:
        return None

    offset, _ = name_table
    count, string_offset = struct.unpack(">HH", data[offset + 2:offset + 6])

    for index in range(count):
        record = offset + 6 + index * 12
        platform_id, encoding_id, _, name_id, length, name_offset = struct.unpack(
            ">HHHHHH", data[record:record + 12]
        )
        if name_id != POSTSCRIPT_NAME_ID:
            continue

        start = offset + string_offset + name_offset
        raw = data[start:start + length]
        # Windows records are UTF-16BE; Macintosh ones are single byte.
        if platform_id == 3 or (platform_id == 0 and encoding_id != 0):
            return raw.decode("utf-16-be", errors="replace")
        return raw.decode("mac-roman", errors="replace")

    return None


def expected_faces() -> dict[str, str]:
    """The PostScript name and file name of every face Typography.swift declares."""
    source = TYPOGRAPHY.read_text(encoding="utf-8")
    names = re.findall(r'case\s+\w+\s*=\s*"([^"]+)"', source)
    return {name: f"{name}.ttf" for name in names}


def listed_in_plist() -> list[str]:
    with INFO_PLIST.open("rb") as handle:
        return plistlib.load(handle).get("UIAppFonts", [])


def main() -> int:
    for path in (INFO_PLIST, TYPOGRAPHY):
        if not path.exists():
            raise SystemExit(f"Not found: {path}. Run this from the repository root.")

    expected = expected_faces()
    listed = listed_in_plist()
    present = {p.name: p for p in sorted(FONT_DIR.glob("*")) if p.suffix.lower() in {".ttf", ".otf"}}

    problems: list[str] = []
    print(f"{'face':<24} {'file':<26} {'listed':<8} {'name inside'}")
    print("-" * 78)

    for face, file_name in expected.items():
        is_listed = file_name in listed
        path = present.get(file_name)

        if path is None:
            inside = "— file missing —"
            problems.append(f"{file_name} is not in {FONT_DIR}")
        else:
            inside = postscript_name(path) or "— unreadable —"
            if inside != face:
                problems.append(
                    f"{file_name} holds a font named {inside!r}, but Typography.swift asks "
                    f"for {face!r}. Rename the case, or use the matching static file."
                )

        if not is_listed:
            problems.append(f"{file_name} is not listed under UIAppFonts in {INFO_PLIST}")

        print(f"{face:<24} {file_name:<26} {'yes' if is_listed else 'NO':<8} {inside}")

    for extra in sorted(set(listed) - {f for f in expected.values()}):
        problems.append(f"{INFO_PLIST} lists {extra}, which no face in Typography.swift uses")
    for extra in sorted(set(present) - {f for f in expected.values()}):
        print(f"  (note: {extra} is present but unused)")

    print()
    if problems:
        print(f"{len(problems)} problem(s):")
        for problem in problems:
            print(f"  - {problem}")
        print("\nUntil these are fixed the app runs on the system font instead.")
        return 1

    print("All faces present, listed, and correctly named.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
