#!/usr/bin/env python3
"""The type the apps are set in, fetched from Google Fonts' own repository.

Three families under the SIL Open Font License, from `google/fonts` (`ofl/`)
at one fixed commit, so running it again writes the same files:

- Chakra Petch (Regular, Medium, SemiBold): HUD labels in capitals and
  figures (`Theme.fontHud`, `fontCaps`). Small, kept as it comes.
- Shippori Mincho (Regular): Japanese words to read closely (`Theme.fontJp`).
- Zen Kaku Gothic New (Regular, Medium, Bold): Japanese in the body text
  (`Theme.fontJpSans`; the sans hands it every Japanese character).

The rest come from outside Google Fonts, so `--cut` makes them from a file
already downloaded, the same way:

- Corporate Logo Bold (LOGOTYPE.JP, SIL Open Font License): Saturn's titles
  and every app's subtitles and big figures (`Theme.fontDisplay`). Its
  licence is `OFL-CorporateLogo.txt`. Its space is half a square, too wide
  between English words, so the cut narrows it (`--space 0.25`). Its em
  dash is made a mark (in GDEF, with no width), so a shaper set it with no
  room at all and a "—" alone (a HeroFigure with no value yet) drew
  nothing; every cut makes such a character a character again, with the
  width its ink needs (the backtick too).

None of these has proportional punctuation (`palt`, which sets 、。「」 in
half a square in a title), so `--palt` gives a cut one, worked out from
where each mark's ink is.
- A world's own title face (Keifont in Terra's app, Yuji Syuku in
  Mercury's) is cut the same way into that world's `assets/fonts/`, when its
  licence allows changing the file. A face whose licence doesn't (Makinas 4
  in Neptune's) is copied as it comes.

The Japanese faces are 2.3 to 15 MB a weight, and every world's binary
carries the kit's fonts, so they are cut down to what Japanese text uses
(kana, the 6,355 kanji of JIS X 0208, the punctuation and full-width forms,
the upright forms for writing down, Latin), without hinting. They stay
TrueType: WOFF2 would be a third of the size, but unpacking it on every
start cost the first frame about 200 ms. A rarer kanji falls back to the
system's Noto CJK. The licence goes beside
each family as OFL-<Family>.txt.

    scripts/fonts.py assets/fonts      # writes the fonts and their licences
    scripts/fonts.py --cut Corporate-Logo-Bold-ver3.otf assets/fonts/CorporateLogo-Bold.otf --space 0.25 --palt

Needs Python 3 with fontTools (`pyftsubset`), and the network (not for `--cut`).
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


def cut(font, to, text):
    """`font` cut down to the characters in the file `text`, written to `to` (TrueType or OpenType, as it was)."""
    subprocess.run([
        "pyftsubset", str(font), f"--text-file={text}",
        "--layout-features=*", "--name-IDs=*", "--no-hinting",
        f"--output-file={to}",
    ], check=True)


def give_widths(font):
    """Makes each character in `font` that is no mark but was made one (classed a mark, which a shaper
    sets with no width, or drawn with no width) a character of its own: classed a base, with the width
    its ink and its left bearing need."""
    import unicodedata

    from fontTools.pens.boundsPen import BoundsPen
    from fontTools.ttLib import TTFont

    f = TTFont(font)
    glyphs = f.getGlyphSet()
    classes = f["GDEF"].table.GlyphClassDef.classDefs if "GDEF" in f and f["GDEF"].table.GlyphClassDef else {}
    changed = False
    for code, name in f.getBestCmap().items():
        if unicodedata.category(chr(code)).startswith("M"):
            continue
        if classes.get(name) == 3:
            classes[name] = 1
            changed = True
        advance, left = f["hmtx"][name]
        if advance:
            continue
        pen = BoundsPen(glyphs)
        glyphs[name].draw(pen)
        if pen.bounds is None or pen.bounds[0] < 0:
            continue
        f["hmtx"][name] = (round(pen.bounds[2] + pen.bounds[0]), left)
        changed = True
    if changed:
        f.save(font)


def narrow_space(font, em):
    """Sets the space's width in `font` (and the no-break space's) to `em` of a square."""
    from fontTools.ttLib import TTFont

    f = TTFont(font)
    width = round(em * f["head"].unitsPerEm)
    cmap = f.getBestCmap()
    for code in (0x20, 0xA0):
        if code in cmap:
            f["hmtx"][cmap[code]] = (width, f["hmtx"][cmap[code]][1])
    f.save(font)


# Punctuation that proportional setting (`palt`) narrows to half a square: the openings keep their
# right half, the closings and the comma and stop their left, the middle dots their middle.
OPENING = "「『（［｛〔【〈《“‘"
CLOSING = "」』）］｝〕】〉》”’、。，．"
MIDDLE = "・：；"


def add_palt(font):
    """Gives `font` proportional Japanese punctuation (`palt`, which `Theme.titleFeatures` turns on), from where each mark's ink is."""
    from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
    from fontTools.pens.boundsPen import BoundsPen
    from fontTools.ttLib import TTFont

    f = TTFont(font)
    em = f["head"].unitsPerEm
    half, pad = em // 2, round(em * 0.05)
    glyphs, cmap = f.getGlyphSet(), f.getBestCmap()
    rules = []
    for c in OPENING + CLOSING + MIDDLE:
        if ord(c) not in cmap:
            continue
        name = cmap[ord(c)]
        advance = f["hmtx"][name][0]
        pen = BoundsPen(glyphs)
        glyphs[name].draw(pen)
        if pen.bounds is None or advance <= half:
            continue
        left, right = pen.bounds[0], pen.bounds[2]
        if c in OPENING:
            start = advance - half if left >= advance - half - pad else max(0, left - pad)
            width = advance - start
        elif c in CLOSING:
            start, width = 0, max(half, right + pad)
        else:
            start, width = (advance - half) // 2, half
        if width < advance:
            rules.append(f"    pos {name} <{-round(start)} 0 {round(width - advance)} 0>;")
    fea = "languagesystem DFLT dflt;\nfeature palt {\n" + "\n".join(rules) + "\n} palt;\n"
    if "GPOS" not in f:
        addOpenTypeFeaturesFromString(f, fea, tables=["GPOS"])
    else:
        # Beside what the face has (its kerning): palt's lookup added to every script's features.
        scratch = TTFont(font)
        del scratch["GPOS"]
        addOpenTypeFeaturesFromString(scratch, fea, tables=["GPOS"])
        theirs, ours = f["GPOS"].table, scratch["GPOS"].table
        base = len(theirs.LookupList.Lookup)
        theirs.LookupList.Lookup.extend(ours.LookupList.Lookup)
        theirs.LookupList.LookupCount = len(theirs.LookupList.Lookup)
        record = ours.FeatureList.FeatureRecord[0]
        record.Feature.LookupListIndex = [i + base for i in record.Feature.LookupListIndex]
        records = theirs.FeatureList.FeatureRecord
        records.append(record)
        # Kept in order of their tags, the order the shaper looks them up in.
        order = sorted(range(len(records)), key=lambda i: records[i].FeatureTag)
        theirs.FeatureList.FeatureRecord = [records[i] for i in order]
        theirs.FeatureList.FeatureCount = len(order)
        moved = {old: new for new, old in enumerate(order)}
        for script in theirs.ScriptList.ScriptRecord:
            systems = [script.Script.DefaultLangSys] + [r.LangSys for r in script.Script.LangSysRecord]
            for system in filter(None, systems):
                system.FeatureIndex = sorted(moved[i] for i in system.FeatureIndex + [len(order) - 1])
                system.FeatureCount = len(system.FeatureIndex)
    f.save(font)


def main():
    if len(sys.argv) >= 4 and sys.argv[1] == "--cut":
        font, to, rest = sys.argv[2], sys.argv[3], sys.argv[4:]
        with tempfile.TemporaryDirectory() as tmp:
            text = Path(tmp) / "japanese.txt"
            text.write_text(japanese())
            cut(font, to, text)
        give_widths(to)
        if "--space" in rest:
            narrow_space(to, float(rest[rest.index("--space") + 1]))
        if "--palt" in rest:
            add_palt(to)
        print(f"{Path(to).stat().st_size:>10,}  {to}")
        return
    if len(sys.argv) != 2:
        sys.exit("usage: scripts/fonts.py <assets/fonts> | --cut <font> <out> [--space <em>] [--palt]")
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        text = tmp / "japanese.txt"
        text.write_text(japanese())
        for folder, prefix, weights, small in FAMILIES:
            fetch(f"{folder}/OFL.txt", out / f"OFL-{prefix}.txt")
            for weight in weights:
                name = f"{prefix}-{weight}.ttf"
                fetch(f"{folder}/{name}", tmp / name)
                if not small:
                    (out / name).write_bytes((tmp / name).read_bytes())
                    continue
                cut(tmp / name, out / name, text)
    for f in sorted(out.iterdir()):
        print(f"{f.stat().st_size:>10,}  {f.name}")


if __name__ == "__main__":
    main()
