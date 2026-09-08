#!/usr/bin/env python3
"""Build the embedded medication lookup database from the TİTCK product list.

TİTCK publishes the "Ruhsatlı Beşeri Tıbbi Ürünler Listesi" as an XLSX roughly
every week, at https://www.titck.gov.tr/dinamikmodul/85. This script finds the
newest one, keeps only the barcode and the product name, and writes them to a
SQLite database the app ships in its bundle so a scanned barcode can be turned
into a product name offline.

Re-run it whenever the list is updated; it overwrites its output in place.

    python3 Tools/build_medication_database.py

Only the standard library is used, so no virtualenv is needed.
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import shutil
import sqlite3
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator
from xml.etree import ElementTree as ET

LISTING_URL = "https://www.titck.gov.tr/dinamikmodul/85"
DEFAULT_OUTPUT = Path("Dozy/Resources/medications.db")

# The published workbook puts a banner on the first row and the real header on
# the second, with the columns we want in B and C.
HEADER_ROW = 2
BARCODE_COLUMN = "B"
NAME_COLUMN = "C"

BARCODE_LENGTH = 13

SPREADSHEET_NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"


@dataclass(frozen=True)
class Release:
    """One published revision of the list."""

    url: str
    date: dt.date

    @property
    def filename(self) -> str:
        return self.url.rsplit("/", 1)[-1]


# MARK: - Discovery


def fetch(url: str) -> bytes:
    """Read a URL, falling back to curl when Python cannot verify the chain.

    A Python installed from python.org ships its own root store, so on a machine
    behind a TLS inspecting proxy the handshake fails here while every other tool
    on the box is fine. curl goes through the system trust store instead, which
    is where such a proxy's certificate is installed.
    """
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            return response.read()
    except urllib.error.URLError as error:
        if not isinstance(error.reason, ssl.SSLError):
            raise
        if not shutil.which("curl"):
            raise

    print("  (Python could not verify the certificate chain; retrying through curl)")
    completed = subprocess.run(
        ["curl", "--silent", "--show-error", "--location", "--max-time", "300",
         "--user-agent", USER_AGENT, url],
        capture_output=True,
        check=True,
    )
    return completed.stdout


def find_latest_release(listing_url: str = LISTING_URL) -> Release:
    """The newest revision linked from the archive page.

    The published filename has changed shape over the years — spaces and Turkish
    characters come and go — so the only things matched on are the word "ruhsat"
    and a dd.mm.yyyy date, both of which have survived every rename so far.
    """
    page = fetch(listing_url).decode("utf-8", errors="replace")

    releases: list[Release] = []
    for href in re.findall(r'href="([^"]+\.xlsx?)"', page):
        name = href.rsplit("/", 1)[-1].lower()
        if "ruhsat" not in name:
            continue

        match = re.search(r"(\d{2})\.(\d{2})\.(\d{4})", name)
        if not match:
            continue

        day, month, year = (int(part) for part in match.groups())
        try:
            releases.append(Release(url=href, date=dt.date(year, month, day)))
        except ValueError:
            continue  # A date the filename only looked like.

    if not releases:
        raise SystemExit(f"No product list found at {listing_url}")

    return max(releases, key=lambda release: release.date)


# MARK: - Reading the workbook


def read_shared_strings(archive: zipfile.ZipFile) -> list[str]:
    """The string table an XLSX keeps its text in, indexed by the cells."""
    if "xl/sharedStrings.xml" not in archive.namelist():
        return []

    root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    return [
        "".join(node.text or "" for node in entry.iter(f"{SPREADSHEET_NS}t"))
        for entry in root
    ]


def read_rows(xlsx_path: Path) -> Iterator[dict[str, str]]:
    """Every row of the first sheet, as {column letter: text}.

    Streamed rather than loaded, since the sheet is a 14 MB XML document.
    """
    with zipfile.ZipFile(xlsx_path) as archive:
        shared_strings = read_shared_strings(archive)

        with archive.open("xl/worksheets/sheet1.xml") as sheet:
            for _, element in ET.iterparse(sheet, events=("end",)):
                if element.tag != f"{SPREADSHEET_NS}row":
                    continue

                yield read_row(element, shared_strings)
                element.clear()


def read_row(element: ET.Element, shared_strings: list[str]) -> dict[str, str]:
    row: dict[str, str] = {}

    for cell in element.findall(f"{SPREADSHEET_NS}c"):
        reference = cell.get("r") or ""
        column = re.match(r"[A-Z]+", reference)
        if not column:
            continue

        value = cell.find(f"{SPREADSHEET_NS}v")
        if cell.get("t") == "s" and value is not None and value.text:
            text = shared_strings[int(value.text)]
        elif value is not None:
            text = value.text or ""
        else:
            # Cells written inline instead of through the string table.
            inline = cell.find(f"{SPREADSHEET_NS}is")
            if inline is None:
                continue
            text = "".join(node.text or "" for node in inline.iter(f"{SPREADSHEET_NS}t"))

        row[column.group(0)] = text

    return row


# MARK: - Normalisation


def normalize_barcode(raw: str) -> str | None:
    """A barcode as 13 digits, or `None` when the cell does not hold one.

    Separators and stray spaces are dropped and anything shorter is padded, which
    is how a scanner reports the same code. Longer values are left alone rather
    than trimmed: the ones in the published list fail their own check digit
    whichever end is cut, so there is no reading of them worth guessing at.
    """
    digits = re.sub(r"\D", "", raw or "")
    if not digits or len(digits) > BARCODE_LENGTH:
        return None

    return digits.zfill(BARCODE_LENGTH)


def normalize_name(raw: str) -> str:
    return " ".join((raw or "").split())


def has_valid_check_digit(barcode: str) -> bool:
    """Whether the barcode satisfies the EAN-13 check digit. Reported, not enforced:
    a product whose printed code is wrong in the list still scans as printed."""
    if len(barcode) != BARCODE_LENGTH or not barcode.isdigit():
        return False

    total = sum(int(digit) * (1 if index % 2 == 0 else 3) for index, digit in enumerate(barcode[:12]))
    return (10 - total % 10) % 10 == int(barcode[12])


# MARK: - Output


def build_database(products: dict[str, str], destination: Path, release: Release) -> None:
    """Write the lookup table, replacing whatever was there before.

    The barcode is the INTEGER PRIMARY KEY, so it *is* the row id: the table is
    stored in barcode order and a lookup needs no secondary index. Anything
    reading this back has to convert its normalised 13 digit string to an
    integer, which drops the leading zeros a handful of short codes were padded
    with — the same conversion on both sides keeps them matching.
    """
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        destination.unlink()

    connection = sqlite3.connect(destination)
    try:
        connection.execute(
            "CREATE TABLE medications (barcode INTEGER PRIMARY KEY, name TEXT NOT NULL)"
        )
        connection.execute("CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")

        connection.executemany(
            "INSERT OR REPLACE INTO medications (barcode, name) VALUES (?, ?)",
            ((int(barcode), name) for barcode, name in products.items()),
        )
        connection.executemany(
            "INSERT INTO metadata (key, value) VALUES (?, ?)",
            [
                ("source_url", release.url),
                ("source_date", release.date.isoformat()),
                ("generated_at", dt.datetime.now().astimezone().isoformat(timespec="seconds")),
                ("product_count", str(len(products))),
            ],
        )
        connection.commit()
        connection.execute("VACUUM")
    finally:
        connection.close()


# MARK: - Driver


def collect_products(xlsx_path: Path) -> tuple[dict[str, str], dict[str, int]]:
    products: dict[str, str] = {}
    counts = {
        "rows": 0,
        "unusable barcode": 0,
        "missing name": 0,
        "duplicate barcode": 0,
        "failed check digit": 0,
    }

    for index, row in enumerate(read_rows(xlsx_path), start=1):
        if index <= HEADER_ROW:
            continue

        counts["rows"] += 1

        barcode = normalize_barcode(row.get(BARCODE_COLUMN, ""))
        if barcode is None:
            counts["unusable barcode"] += 1
            continue

        name = normalize_name(row.get(NAME_COLUMN, ""))
        if not name:
            counts["missing name"] += 1
            continue

        if not has_valid_check_digit(barcode):
            counts["failed check digit"] += 1

        # The list repeats a barcode when a product is re-registered; the first
        # entry is the current one.
        if barcode in products:
            counts["duplicate barcode"] += 1
            continue

        products[barcode] = name

    return products, counts


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--source",
        help="Path to an already downloaded XLSX. Defaults to downloading the newest published one.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Where to write the database (default: {DEFAULT_OUTPUT}).",
    )
    parser.add_argument(
        "--keep-download",
        type=Path,
        help="Also save the downloaded XLSX here, for inspection.",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()

    with tempfile.TemporaryDirectory() as workspace:
        if arguments.source:
            xlsx_path = Path(arguments.source)
            if not xlsx_path.exists():
                raise SystemExit(f"No such file: {xlsx_path}")
            release = Release(url=str(xlsx_path), date=dt.date.today())
            print(f"Reading {xlsx_path}")
        else:
            release = find_latest_release()
            print(f"Newest published list: {release.filename} ({release.date:%d.%m.%Y})")

            xlsx_path = Path(workspace) / "list.xlsx"
            xlsx_path.write_bytes(fetch(release.url))
            print(f"Downloaded {xlsx_path.stat().st_size / 1_048_576:.1f} MB")

            if arguments.keep_download:
                arguments.keep_download.parent.mkdir(parents=True, exist_ok=True)
                arguments.keep_download.write_bytes(xlsx_path.read_bytes())

        products, counts = collect_products(xlsx_path)

    if not products:
        raise SystemExit("The list produced no usable rows; has its layout changed?")

    build_database(products, arguments.output, release)

    size = arguments.output.stat().st_size
    print()
    print(f"Wrote {arguments.output}")
    print(f"  products : {len(products):,}")
    print(f"  size     : {size:,} bytes ({size / 1_048_576:.2f} MB)")
    print(f"  from     : {counts['rows']:,} data rows")
    for label in ("unusable barcode", "missing name", "duplicate barcode"):
        if counts[label]:
            print(f"  skipped  : {counts[label]:,} ({label})")
    if counts["failed check digit"]:
        print(f"  note     : {counts['failed check digit']:,} kept despite a failing EAN-13 check digit")

    return 0


if __name__ == "__main__":
    sys.exit(main())
