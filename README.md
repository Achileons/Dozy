# Dozy

An iOS medication reminder app: what to take, when to take it, and what is left
in the package.

## Medication database

`Dozy/Resources/medications.db` maps a barcode to a product name, so scanning a
package can name the medication without a network call. It is generated from the
"Ruhsatlı Beşeri Tıbbi Ürünler Listesi" that TİTCK publishes weekly at
<https://www.titck.gov.tr/dinamikmodul/85>, and holds only those two columns —
roughly 23,000 products in about 1.4 MB.

Regenerate it whenever the published list is updated:

```bash
python3 Tools/build_medication_database.py
```

The script finds the newest list on that page, downloads it, and rewrites the
database in place. It needs nothing beyond the standard library, and prints what
it wrote, what it skipped, and the resulting file size. Pass `--source` to build
from an XLSX you already have, or `--output` to write somewhere else.

A schema note for the lookup side: `barcode` is an `INTEGER PRIMARY KEY`, so the
table is stored in barcode order and needs no secondary index. Convert a scanned
barcode to 13 digits and then to an integer before querying — a handful of short
codes are zero padded, and the leading zeros only survive if both sides do the
same conversion.
