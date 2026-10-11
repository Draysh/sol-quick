#!/usr/bin/env bash
# The one look after a kit change: builds the gallery once, then takes a
# picture of every page, night and day (and two narrow), into <folder>,
# and says what the journal had to say about the QML while they were taken.
#
#   scripts/gallery-shots.sh [--build] <folder> [name…]
#
# The kit's QML and the gallery's are read from this checkout
# (SOL_QML_LIVE=1), so after an edit to .qml files alone it takes the
# pictures without building; it builds when anything else changed, when a
# .qml file was added or removed (the module lists them), or with --build.
#
# With names (e.g. `night-controls day-panels`), only the pictures whose
# names start with one of them. The pictures are taken in a few runs of the
# gallery (night, day, with less motion, narrow), each on a hidden display
# of its own (scripts/hidden.sh) and taking its pictures one after another
# as each page is ready (SOL_SHOTS): no window ever opens on the person's
# desktop.
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

# Mercury and Sol, which have no moons, last: a Sheet whose world gains a moon while it shows
# places the moon's link wrong (only the gallery changes its world while running).
worlds=(terra luna saturn titan neptune triton mercury sol)
echo "Pictures in $out:"
for light in night day; do
    # First: the problem takes the place of the Shell, which then loads for the rest.
    if [[ $light == night ]]; then shoot "night-problem-newer" "/?_problem=newer"; else shoot "day-problem-damaged" "/?_problem=damaged"; fi
    for w in "${worlds[@]}"; do shoot "$light-worlds-$w" "/?_world=$w"; done
    shoot "$light-worlds-lower" "/?_world=terra&_scroll=1100"
    shoot "$light-controls" "/controls"
    shoot "$light-controls-lower" "/controls?_scroll=900"
    shoot "$light-panels" "/panels"
    shoot "$light-panels-lower" "/panels?_scroll=1000"
    shoot "$light-panels-end" "/panels?_scroll=2300"
    shoot "$light-panels-long" "/panels?_scroll=5000"
    shoot "$light-overlays" "/overlays"
    shoot "$light-overlays-menu" "/overlays?_menu=1"
    if [[ $light == night ]]; then
        # The states one picture can't hold, at night only.
        shoot "night-controls-field" "/controls?_focus=field"
        shoot "night-controls-textarea" "/controls?_focus=textarea"
        shoot "night-overlays-palette" "/overlays?_palette=1"
        shoot "night-overlays-ask" "/overlays?_ask=1"
        shoot "night-overlays-notice" "/overlays?_notice=1"
        shoot "night-overlays-notice-button" "/overlays?_notice=button"
        shoot "night-overlays-kept" "/overlays?_kept=1"
        shoot "night-overlays-moment" "/overlays?_moment=1"
        # Quick capture: its own window's picture lands beside, as <name>-capture.png.
        shoot "night-overlays-capture" "/overlays?_capture=walk"
        shoot "night-overlays-tour" "/overlays?_tour=1"
        # Last: the open list stays open over what comes after.
        shoot "night-controls-select" "/controls?_focus=select"
    else
        shoot "day-overlays-moment" "/overlays?_moment=1"
        shoot "day-overlays-kept" "/overlays?_kept=1"
        shoot "day-overlays-tour" "/overlays?_tour=2"
    fi
    run SOL_LIGHT="$light"
done
shoot "night-overlays-moment-calm" "/overlays?_moment=1"
run SOL_LIGHT=night SOL_CALM=1
# Narrow: the sidebar as a rail, one column.
shoot "narrow-worlds" "/?_world=saturn"
shoot "narrow-controls" "/controls"
run SOL_LIGHT=night QT_SCALE_FACTOR=3

echo "The journal since $start:"
if journalctl --user -S "$start" | grep 'gallery\[' \
    | grep -v 'not-there' | grep -E 'TypeError|ReferenceError|Cannot assign|Unable to assign|[Bb]inding loop|\.qml:[0-9]+|failed to load|SOL_SHOT'; then
    exit 1
fi
echo "  nothing from the QML"
