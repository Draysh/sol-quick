#!/usr/bin/env bash
# Takes many pictures of a world's app in one run: one hidden display, one
# launch of its preview, the pictures one after another (each once its page
# is ready), then what the journal said about the QML while they were taken.
# Builds nothing: it runs the debug binary as it is, reading the kit's and
# the world's QML from their checkouts (so after a .qml edit, just run it
# again; after a Rust edit or a new .qml file, build the world first).
#
#   scripts/shots.sh <world> <folder> <name>=<path?keys>…
#   scripts/shots.sh <world> <folder> --file <list>
#   scripts/shots.sh saturn /tmp/s home=/ home-end='/?_scroll=end' library='/library?_scroll=1200'
#
# Each picture is <folder>/<name>.png. A path takes the staging keys of the
# kit's README (`_scroll=N|end`, `_palette`, `_capture=<line>`, `_moment=…`,
# `_after=<ms>`); a list file has one `<name>=<path>` a line (`#` starts a
# comment). The run's environment goes through: SOL_LIGHT=day,
# QT_SCALE_FACTOR=3 (narrow), SOL_SHOT_CALM=1 (no arrivals), SOL_SHOT_AFTER
# (the most one picture waits, 8000 ms). `gallery` as the world is the
# kit's gallery. Exits non-zero when a picture is missing or the QML said
# something wrong.
set -euo pipefail

usage() { echo "usage: $0 <world> <folder> (<name>=<path>… | --file <list>)" >&2; exit 64; }
[[ $# -ge 3 ]] || usage
world=$1 out=$2
shift 2
mkdir -p "$out"
out=$(cd "$out" && pwd)
kit=$(cd "$(dirname "$0")/.." && pwd)

specs=()
if [[ $1 == --file ]]; then
    [[ -f ${2:-} ]] || usage
    while IFS= read -r line || [[ -n $line ]]; do
        line=${line%%#*}
        line=$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"$line")
        [[ -n $line ]] && specs+=("$line")
    done <"$2"
else
    specs=("$@")
fi
[[ ${#specs[@]} -gt 0 ]] || usage

target=$(cd "$kit" && cargo metadata --format-version 1 --no-deps 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['target_directory'])")
if [[ $world == gallery ]]; then bin=$target/debug/examples/gallery; tag=gallery; else bin=$target/debug/$world; tag=$world; fi
[[ -x $bin ]] || { echo "no $bin: build it first (cargo build in worlds/$world)" >&2; exit 66; }

# The list the app reads: absolute file names, `;` apart.
list=() pngs=()
for s in "${specs[@]}"; do
    [[ $s == *=* ]] || { echo "not <name>=<path>: $s" >&2; exit 64; }
    name=${s%%=*} path=${s#*=}
    png=$out/${name%.png}.png
    rm -f "$png" "${png%.png}-capture.png"
    pngs+=("$png")
    list+=("$png=$path")
done
joined=$(IFS=';'; echo "${list[*]}")

start=$(date '+%Y-%m-%d %H:%M:%S')
# The most the run may take: every picture at its longest, and the start.
after=${SOL_SHOT_AFTER:-8000}
limit=$(( 20 + ${#pngs[@]} * (after / 1000 + 2) ))
status=0
"$kit/scripts/capped" "$kit/scripts/hidden.sh" -- env SOL_PREVIEW=1 SOL_SHOTS="$joined" \
    timeout "$limit" "$bin" >/dev/null 2>&1 || status=$?

missing=0
echo "Pictures in $out:"
for png in "${pngs[@]}"; do
    if [[ -s $png ]]; then echo "  $(basename "$png")"; else echo "  $(basename "$png"): no picture"; missing=1; fi
done
[[ $status -eq 0 ]] || echo "  (the app ended with $status)"

echo "The journal since $start:"
lines=$(journalctl --user -S "$start" | grep "$tag\[" || true)
wrong=$(echo "$lines" | grep -v 'not-there' \
    | grep -E 'TypeError|ReferenceError|Cannot assign|Unable to assign|[Bb]inding loop|\.qml:[0-9]+|failed to load|SOL_SHOT' || true)
if [[ -n $wrong ]]; then echo "$wrong" | sed 's/^/  /'; else echo "  nothing from the QML"; fi
if [[ -n $(echo "$wrong" | grep -v "SOL_SHOT: .* wasn't ready" || true) || $missing -ne 0 ]]; then exit 1; fi
