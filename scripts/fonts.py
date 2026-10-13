#!/usr/bin/env python3
"""The type the apps are set in, fetched from Google Fonts' own repository.

Three families under the SIL Open Font License, from `google/fonts` (`ofl/`)
at one fixed commit, so running it again writes the same files:

- Chakra Petch (Regular, Medium, SemiBold): HUD labels in capitals and
  figures (`Theme.fontHud`, `fontCaps`). Small, kept as it comes.
- Shippori Mincho B1 (ExtraBold): titles (`Theme.fontTitle`).
- Shippori Mincho (Regular): Japanese words to read closely (`Theme.fontJp`).
- Zen Kaku Gothic New (Regular, Medium, Bold): Japanese in the body text
  (`Theme.fontJpSans`; the sans hands it every Japanese character).

The Japanese faces are 2.3 to 15 MB a weight, and every world's binary
carries the kit's fonts, so they are cut down to what Japanese text uses
(kana, the 6,355 kanji of JIS X 0208, the punctuation and full-width forms,
the upright forms for writing down, Latin), without hinting. They stay
TrueType: WOFF2 would be a third of the size, but unpacking it on every
start cost the first frame about 200 ms. A rarer kanji falls back to the
system's Noto CJK. The licence goes beside
each family as OFL-<Family>.txt.

    scripts/fonts.py assets/fonts      # writes the fonts and their licences

Needs Python 3 with fontTools (`pyftsubset`), and the network.
"""

import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

COMMIT = "66928797f271fed5ee428544e7229685e2d90127"
BASE = f"https://raw.githubusercontent.com/google/fonts/{COMMIT}/ofl"

# (folder in ofl/, family's file prefix, weights, whether to cut it down)
FAMILIES = [
    ("chakrapetch", "ChakraPetch", ["Regular", "Medium", "SemiBold"], False),
    ("shipporiminchob1", "ShipporiMinchoB1", ["ExtraBold"], True),
    ("shipporimincho", "ShipporiMincho", ["Regular"], True),
    ("zenkakugothicnew", "ZenKakuGothicNew", ["Regular", "Medium", "Bold"], True),
]


def japanese():
    """Every character Japanese text needs: JIS X 0208 (kana, kanji levels 1 and 2), plus ranges around it."""
    chars = set()
    for a in range(0xA1, 0xFF):
        for b in range(0xA1, 0xFF):
            try:
                chars.add(bytes([a, b]).decode("euc_jp"))
            except UnicodeDecodeError:
                pass
    for lo, hi in [(0x20, 0x7F), (0xA0, 0x180), (0x2000, 0x206F), (0x2190, 0x21FF),
                   (0x2460, 0x24FF), (0x25A0, 0x26FF), (0x3000, 0x30FF), (0x31F0, 0x31FF),
                   (0xFE10, 0xFE20), (0xFE30, 0xFE50), (0xFF00, 0xFFEF)]:
        chars.update(chr(c) for c in range(lo, hi))
    return "".join(sorted(chars))


def fetch(path, to):
    with urllib.request.urlopen(f"{BASE}/{path}") as r:
        to.write_bytes(r.read())


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: scripts/fonts.py <assets/fonts>")
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        text = tmp / "japanese.txt"
        text.write_text(japanese())
        for folder, prefix, weights, cut in FAMILIES:
            fetch(f"{folder}/OFL.txt", out / f"OFL-{prefix}.txt")
            for weight in weights:
                name = f"{prefix}-{weight}.ttf"
                fetch(f"{folder}/{name}", tmp / name)
                if not cut:
                    (out / name).write_bytes((tmp / name).read_bytes())
                    continue
                subprocess.run([
                    "pyftsubset", str(tmp / name), f"--text-file={text}",
                    "--layout-features=*", "--name-IDs=*", "--no-hinting",
                    f"--output-file={out / name}",
                ], check=True)
    for f in sorted(out.iterdir()):
        print(f"{f.stat().st_size:>10,}  {f.name}")


if __name__ == "__main__":
    main()
