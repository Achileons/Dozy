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

## Fonts

The app is set in two faces: **Quicksand** for the words that name something (screen
titles, the month, a day) and **Nunito** for everything else. Both are Google Fonts,
licensed under the SIL Open Font License.

The `.ttf` files are not in the repository. Drop these five into
`Dozy/Resources/Fonts/`:

| File | From |
| --- | --- |
| `Quicksand-SemiBold.ttf` | <https://fonts.google.com/specimen/Quicksand> |
| `Quicksand-Bold.ttf` | same download |
| `Nunito-Regular.ttf` | <https://fonts.google.com/specimen/Nunito> |
| `Nunito-SemiBold.ttf` | same download |
| `Nunito-Bold.ttf` | same download |

Google Fonts hands you a zip containing a **variable** font at the top level
(`Quicksand[wght].ttf`) and the fixed weights in a `static/` subfolder. Take the ones from
`static/` — the names above are exactly the file names in there. A variable font registers
but its individual weights cannot be selected by PostScript name, which is how the app asks
for them.

No Xcode step is needed. `Dozy/` is a file-system-synchronized group, so anything inside it
joins the target automatically; dropping the files in the folder is the whole job. The five
names are already listed under `UIAppFonts` in `Dozy/Info.plist`.

Then check they took:

```bash
python3 Tools/check_fonts.py
```

It reads the PostScript name out of each file and compares it against what
`Dozy/Theme/Typography.swift` asks for and what `Info.plist` lists. That last comparison is
the one worth having: the name inside a font is set by whoever built it and need not match
the file name, and when it does not match, iOS silently draws the system face instead of
telling you. Running the app in Debug prints the same warning once at launch.

Until the files are added the app runs on the system font throughout — every style declares
a deliberate fallback, so nothing breaks and no layout moves.

### Changing the type

Every size, weight, face and tracking value lives in `Dozy/Theme/Typography.swift`, in the
`TextRole` enum. Views never name a font size; they say what a piece of text *is*
(`.textStyle(.headline)`), and the role decides how that looks.
