#!/usr/bin/env bash
# The one look after a kit change: builds the gallery once, then takes a
# picture of every page in each world's flavour (Saturn's, Mercury's,
# Neptune's, Terra's), with less motion and narrow, into <folder>, and says
# what the journal had to say about the QML while they were taken.
#
#   scripts/gallery-shots.sh [--build] <folder> [name…]
#
# The kit's QML and the gallery's are read from this checkout
# (SOL_QML_LIVE=1), so after an edit to .qml files alone it takes the
# pictures without building; it builds when anything else changed, when a
# .qml file was added or removed (the module lists them), or with --build.
#
# With names (e.g. `saturn-controls terra-panels`), only the pictures whose
# names start with one of them. Each page is taken from its top to its end, a
# view at a time (`saturn-panels`, `saturn-panels-2` … `saturn-panels-end`),
# so every component is in a picture; a view that only repeats the one
# before (the page ended sooner) is dropped. The pictures are taken in a few
# runs of the gallery (one per flavour, SOL_FLAVOUR=<world>, Luna's too; with
# less motion; narrow),
# each on a hidden display of its own (scripts/hidden.sh) and taking its
# pictures one after another as each page is ready (SOL_SHOTS): no window
# ever opens on the person's desktop.
set -euo pipefail

build=
if [[ ${1:-} == --build ]]; then build=1; shift; fi
out=${1:?usage: scripts/gallery-shots.sh [--build] <folder> [name…]}
shift
only=("$@")
mkdir -p "$out"
out=$(cd "$out" && pwd)
cd "$(dirname "$0")/.."
kit=$(pwd)

bin=$(cargo metadata --format-version 1 --no-deps 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['target_directory'])")/debug/examples/gallery
# The .qml files the last build compiled into the module, beside the binary.
listed=$bin.qml-files
qml_files() { find qml -name '*.qml' | sort; }
if [[ -z $build && ( ! -x $bin || ${SOL_QML_LIVE:-1} != 1 ) ]]; then build=1; fi
if [[ -z $build ]] && ! qml_files | cmp -s - "$listed"; then build=1; fi
if [[ -z $build ]] && [[ -n $(find build.rs Cargo.toml Cargo.lock src core cpp assets shaders examples/gallery/main.rs ../orbit/src \
    -newer "$bin" -not -name '*.qml' -print -quit 2>/dev/null) ]]; then build=1; fi
if [[ -n $build ]]; then
    scripts/capped cargo build --example gallery
    qml_files >"$listed"
else
    echo "Only .qml changed since the last build: reading it from the checkout, no build."
fi

# The worlds' own title faces, when their checkouts sit beside the kit (as in
# a checkout of Sol): each world's app carries its own, the kit doesn't, so
# the gallery is handed them (SOL_FONTS) to show each flavour in its face.
fonts=()
for f in ../../worlds/terra/assets/fonts/Keifont.ttf ../../worlds/mercury/assets/fonts/YujiSyuku-Regular.ttf \
    ../../worlds/neptune/assets/fonts/Makinas-4-Square.otf; do
    [[ -f $f ]] && fonts+=("$(cd "$(dirname "$f")" && pwd)/$(basename "$f")")
done
export SOL_FONTS=$(IFS=:; echo "${fonts[*]}")

# A fresh throwaway copy, so the window opens at its own size.
rm -rf /tmp/sol-preview-gallery
start=$(date '+%Y-%m-%d %H:%M:%S')

wanted() {
    [ ${#only[@]} -eq 0 ] && return 0
    for o in "${only[@]}"; do [[ $1 == "$o"* ]] && return 0; done
    return 1
}

# shoot <name> <path>: one more picture for the run being gathered.
batch=() names=()
shoot() {
    wanted "$1" || return 0
    rm -f "$out/$1.png" "$out/$1-capture.png"
    batch+=("$out/$1.png=$2")
    names+=("$1")
}
# down <name> <path> <views>: the page from its top to its end, a view (700 px, a little less than the window) at a time:
# <name>, <name>-2 … and <name>-end; the views that repeat the one before are dropped at the end.
step=700
downs=()
down() {
    local name=$1 path=$2 views=$3 sep='?' k
    [[ $path == *\?* ]] && sep='&'
    shoot "$name" "$path"
    for ((k = 1; k < views; k++)); do shoot "$name-$((k + 1))" "$path${sep}_scroll=$((k * step))"; done
    shoot "$name-end" "$path${sep}_scroll=end"
    wanted "$name" && downs+=("$name:$views")
    return 0
}
# run [VAR=value…]: takes the gathered pictures in one run of the gallery;
# once more for any that didn't come (a window the desktop never showed).
run() {
    [ ${#batch[@]} -eq 0 ] && return 0
    local todo=("${batch[@]}") left n
    for _ in 1 2; do
        local list
        list=$(IFS=';'; echo "${todo[*]}")
        env "$@" SOL_SHOTS="$list" scripts/capped scripts/hidden.sh -- \
            timeout $(( 20 + ${#todo[@]} * 10 )) "$bin" >/dev/null 2>&1 || true
        left=()
        for e in "${todo[@]}"; do [ -s "${e%%=*}" ] || left+=("$e"); done
        [ ${#left[@]} -eq 0 ] && break
        todo=("${left[@]}")
    done
    for n in "${names[@]}"; do
        if [ -s "$out/$n.png" ]; then echo "  $n"; else echo "  $n: no picture"; fi
    done
    batch=() names=()
}

echo "Pictures in $out:"
# Each flavour's run: its own world's page (and its moon's), then every page of the gallery.
# Luna's flavour is her own (a moon's), worn on its own run.
declare -A moon=([saturn]=titan [mercury]= [neptune]=triton [terra]=luna [luna]=)
for f in saturn mercury neptune terra luna; do
    # First: the problem takes the place of the Shell, which then loads for the rest.
    if [[ $f == saturn ]]; then shoot "saturn-problem-newer" "/?_problem=newer"; fi
    if [[ $f == terra ]]; then shoot "terra-problem-damaged" "/?_problem=damaged"; fi
    down "$f-worlds" "/?_world=$f" 3
    [[ -n ${moon[$f]} ]] && shoot "$f-worlds-${moon[$f]}" "/?_world=${moon[$f]}"
    down "$f-controls" "/controls" 3
    down "$f-panels" "/panels" 10
    down "$f-overlays" "/overlays" 2
    shoot "$f-overlays-menu" "/overlays?_menu=1"
    shoot "$f-overlays-moment" "/overlays?_moment=1"
    shoot "$f-sky" "/sky"
    down "$f-tabs" "/tabs" 2
    down "$f-settings" "/settings" 2
    if [[ $f == saturn ]]; then
        # The states one picture can't hold, in one flavour only.
        shoot "saturn-controls-field" "/controls?_focus=field"
        shoot "saturn-controls-textarea" "/controls?_focus=textarea"
        shoot "saturn-overlays-palette" "/overlays?_palette=1"
        shoot "saturn-overlays-ask" "/overlays?_ask=1"
        shoot "saturn-overlays-notice" "/overlays?_notice=1"
        shoot "saturn-overlays-notice-button" "/overlays?_notice=button"
        shoot "saturn-overlays-kept" "/overlays?_kept=1"
        # Quick capture: its own window's picture lands beside, as <name>-capture.png.
        shoot "saturn-overlays-capture" "/overlays?_capture=walk"
        shoot "saturn-overlays-tour" "/overlays?_tour=1"
        # The Sky's own: a star chosen, the full moon on Luna's Sheet, a star lighting.
        shoot "saturn-sky-chosen" "/sky?star=ghibli/spirited"
        shoot "saturn-worlds-full-moon" "/?_world=luna&_sky=full-moon"
        shoot "saturn-sky-star" "/sky?_moment=star"
        # A carried moon: its group in the sidebar, its pages in its colour, on its own link; its sky a tab
        # of the Sky and its settings a part of Settings, which its old paths still open.
        shoot "saturn-moon" "/moon"
        shoot "saturn-moon-sky" "/moon/sky"
        shoot "saturn-moon-settings" "/moon/settings"
        # Structure: a section's children open, a page's tabs, things' menus, the palette's nested row.
        shoot "saturn-tabs-calendar" "/tabs?tab=calendar"
        shoot "saturn-menus" "/menus"
        shoot "saturn-menus-open" "/menus?_nested=1"
        shoot "saturn-overlays-palette-rate" "/overlays?_palette=rate"
        # Last: the open list stays open over what comes after.
        shoot "saturn-controls-select" "/controls?_focus=select"
    fi
    run SOL_FLAVOUR="$f"
done
shoot "calm-overlays-moment" "/overlays?_moment=1"
run SOL_CALM=1
# Narrow: the sidebar as a rail, one column.
shoot "narrow-worlds" "/?_world=saturn"
shoot "narrow-controls" "/controls"
shoot "narrow-tabs" "/tabs"
run QT_SCALE_FACTOR=3

# The views that only repeat the one before them (the page ended sooner): dropped.
if [ ${#downs[@]} -gt 0 ]; then
    python3 - "$out" "${downs[@]}" <<'PY'
import sys
from pathlib import Path
from PIL import Image, ImageChops
out = Path(sys.argv[1])
def same(a, b):
    if not (a.exists() and b.exists()):
        return False
    x, y = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    if x.size != y.size:
        return False
    d = ImageChops.difference(x, y).convert("L").point(lambda v: 255 if v > 24 else 0)
    return d.histogram()[255] < 300
for arg in sys.argv[2:]:
    name, views = arg.rsplit(":", 1)
    names = [name] + [f"{name}-{k}" for k in range(2, int(views) + 1)] + [f"{name}-end"]
    kept = None
    for n in names:
        p = out / f"{n}.png"
        if not p.exists():
            continue
        if kept is not None and same(kept, p):
            p.unlink()
            continue
        kept = p
PY
fi

echo "The journal since $start:"
if journalctl --user -S "$start" | grep 'gallery\[' \
    | grep -v 'not-there' | grep -E 'TypeError|ReferenceError|Cannot assign|Unable to assign|[Bb]inding loop|\.qml:[0-9]+|failed to load|SOL_SHOT'; then
    exit 1
fi
echo "  nothing from the QML"
