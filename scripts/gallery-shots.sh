#!/usr/bin/env bash
# The one look after a kit change: builds the gallery once, then takes a
# picture of every page, night and day (and two narrow), into <folder>,
# and says what the journal had to say about the QML while they were taken.
#
#   scripts/gallery-shots.sh <folder> [name…]
#
# With names (e.g. `night-controls day-panels`), only the pictures whose
# names start with one of them. Every picture is taken on a hidden display
# (scripts/hidden.sh, one for the whole batch), one after another: no window
# ever opens on the person's desktop.
set -euo pipefail

if [[ ${WAYLAND_DISPLAY:-} != hidden ]]; then
    exec "$(dirname "$0")/hidden.sh" -- "$0" "$@"
fi

out=${1:?usage: scripts/gallery-shots.sh <folder> [name…]}
shift
only=("$@")
mkdir -p "$out"
out=$(cd "$out" && pwd)
cd "$(dirname "$0")/.."

cargo build --example gallery
bin=$PWD/target/debug/examples/gallery

# A fresh throwaway copy, so the window opens at its own size.
rm -rf /tmp/sol-preview-gallery
start=$(date '+%Y-%m-%d %H:%M:%S')

wanted() {
    [ ${#only[@]} -eq 0 ] && return 0
    for o in "${only[@]}"; do [[ $1 == "$o"* ]] && return 0; done
    return 1
}

# shoot <name> <light> <path> [VAR=value…]
shoot() {
    local name=$1 light=$2 path=$3
    shift 3
    wanted "$name" || return 0
    local png=$out/$name.png
    rm -f "$png"
    # Once more if the picture didn't come (a window the desktop never showed).
    for _ in 1 2; do
        env SOL_LIGHT="$light" SOL_SHOT="$png" SOL_SHOT_AFTER=4500 SOL_SHOT_PATH="$path" "$@" \
            timeout 30 "$bin" >/dev/null 2>&1 || true
        [ -s "$png" ] && break
    done
    if [ -s "$png" ]; then echo "  $name"; else echo "  $name: no picture"; fi
}

worlds=(terra luna saturn titan mercury neptune triton sol)
echo "Pictures in $out:"
for light in night day; do
    for w in "${worlds[@]}"; do shoot "$light-worlds-$w" "$light" "/?_world=$w"; done
    shoot "$light-worlds-lower" "$light" "/?_world=terra&_scroll=1100"
    shoot "$light-controls" "$light" "/controls"
    shoot "$light-controls-lower" "$light" "/controls?_scroll=900"
    shoot "$light-panels" "$light" "/panels"
    shoot "$light-panels-lower" "$light" "/panels?_scroll=1000"
    shoot "$light-panels-end" "$light" "/panels?_scroll=2300"
    shoot "$light-overlays" "$light" "/overlays"
    shoot "$light-overlays-menu" "$light" "/overlays?_menu=1"
done
# The states one picture can't hold, at night only.
shoot "night-controls-field" night "/controls?_focus=field"
shoot "night-controls-textarea" night "/controls?_focus=textarea"
shoot "night-controls-select" night "/controls?_focus=select"
shoot "night-overlays-palette" night "/overlays?_palette=1"
shoot "night-overlays-ask" night "/overlays?_ask=1"
shoot "night-overlays-notice" night "/overlays?_notice=1"
shoot "night-overlays-notice-button" night "/overlays?_notice=button"
shoot "night-overlays-kept" night "/overlays?_kept=1"
shoot "day-overlays-kept" day "/overlays?_kept=1"
shoot "night-problem-newer" night "/?_problem=newer"
shoot "day-problem-damaged" day "/?_problem=damaged"
# Narrow: the sidebar as a rail, one column.
shoot "narrow-worlds" night "/?_world=saturn" QT_SCALE_FACTOR=3
shoot "narrow-controls" night "/controls" QT_SCALE_FACTOR=3

echo "The journal since $start:"
if journalctl --user -S "$start" | grep 'gallery\[' \
    | grep -v 'not-there' | grep -E 'TypeError|ReferenceError|Cannot assign|Unable to assign|[Bb]inding loop|\.qml:[0-9]+|failed to load'; then
    exit 1
fi
echo "  nothing from the QML"
