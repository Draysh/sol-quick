#!/usr/bin/env bash
# The Yozora look's pictures, fetched for this computer only: each world's
# grounds (wide stills from a Makoto Shinkai film, from TMDB's image CDN)
# and its navigator (a character's portrait, from AniList), into
# ~/.local/share/sol-yozora/ as <world>-ground-<n>.jpg and
# <world>-mascot.jpg. The pictures belong to their makers: they are never
# copied into a repository, a fixture or a release. This script holds only
# where they come from.
#
#   scripts/yozora-art.sh            fetch what is missing
#   scripts/yozora-art.sh --again    fetch every one again
#   scripts/yozora-art.sh --stills <tmdb-film-id> <folder>
#                                    small copies of every textless still of a
#                                    film, to choose grounds from
#
# The TMDB key is Saturn's own (its settings in the installed app's local
# copy), or $TMDB_KEY; it is handed to curl on stdin, never printed or put
# on a command line. AniList needs no key.
set -euo pipefail

out=${SOL_YOZORA_DIR:-$HOME/.local/share/sol-yozora}
saturn_db=$HOME/.local/share/digital.sachi.sol.saturn/saturn.db

# Each world's grounds: "<tmdb film id>:<still's file>" (Saturn and Titan:
# Suzume; Mercury: Your Name; Neptune and Triton: Weathering With You;
# Terra: midsummer skies from Weathering With You and 5 Centimeters per
# Second). A moon with grounds of its own stands on them instead of its
# planet's (Luna: the sky after sunset and the moon, from 5 Centimeters per
# Second).
declare -A grounds=(
    [saturn]="916224:/4AqzAaqztV2rEOJswoV12G7I4jF.jpg 916224:/sx0CyonBRpLjas1g1qyxRao7rMf.jpg 916224:/fLvSBInChNHZbwVkix1p8cri7B1.jpg"
    [mercury]="372058:/9l7yHJVCuqgZn5IvnsRl5XDvOpy.jpg 372058:/u4DNyWCQ6VTjJY4GisbeAXSJz9a.jpg 372058:/rjs5IfIv6Psl2YCSHKcluhTQGjJ.jpg"
    [neptune]="568160:/rf4KVKAjV8z6JtSiwaadvpBzS6H.jpg 568160:/mBl7B4r5k0PFTBPd0uTacm2ml4O.jpg 568160:/kXoFwmhLuWs2tY720IsuTBSolKX.jpg"
    [terra]="568160:/uoWyHkGQindLosblL7fAnkVaZlj.jpg 38142:/10oKmdkzxChD6m2DsPZhWkFxVIY.jpg 568160:/hcnPXKjHeJtLpYjjVwUAX9MsFcJ.jpg"
    [luna]="38142:/n7dz2NHNuEvoreUM4qXFR0Yh0pw.jpg 38142:/8kH9XcdkQbh2kSx4mdPu3vSrSbh.jpg"
)
# Each world's navigator: "<AniList media id>:<the character's full name>"
# (Suzume Iwato, Mitsuha Miyamizu, Lucy of Cyberpunk: Edgerunners, Hina Amano).
declare -A mascots=(
    [saturn]="142770:Suzume Iwato"
    [mercury]="21519:Mitsuha Miyamizu"
    [neptune]="120377:Lucy"
    [terra]="106286:Hina Amano"
)

tmdb_key() {
    if [[ -n ${TMDB_KEY:-} ]]; then printf '%s' "$TMDB_KEY"; return; fi
    [[ -f $saturn_db ]] || { echo "No TMDB key: set TMDB_KEY, or set one in Saturn." >&2; exit 1; }
    sqlite3 -readonly "$saturn_db" "select value from meta where key='settings';" \
        | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("tmdb_key","").strip(), end="")'
}

# A TMDB API call (path and query after /3), its JSON on stdout.
tmdb() {
    local key
    key=$(tmdb_key)
    [[ -n $key ]] || { echo "Saturn has no TMDB key." >&2; exit 1; }
    if [[ $key == eyJ* ]]; then
        printf 'Authorization: Bearer %s\n' "$key" | curl -fsS --max-time 30 -H @- "https://api.themoviedb.org/3$1"
    else
        # A v3 key goes in the query: read from stdin into curl's config, so it stays off the command line.
        local sep='?'; [[ $1 == *\?* ]] && sep='&'
        printf 'url = "https://api.themoviedb.org/3%s%sapi_key=%s"\n' "$1" "$sep" "$key" | curl -fsS --max-time 30 -K -
    fi
}

# A file from the web into place, only when it came whole.
fetch() {
    local url=$1 to=$2
    curl -fsSL --max-time 120 -o "$to.part" "$url"
    # A portrait may come as a PNG: kept as a JPEG, as its name says.
    if [[ $url == *.png ]] && command -v magick >/dev/null; then
        magick "png:$to.part" -quality 92 "jpg:$to" && rm "$to.part"
    else
        mv "$to.part" "$to"
    fi
    printf '%s\t%s\t%s\n' "$(basename "$to")" "$(du -h "$to" | cut -f1)" "$url"
}

if [[ ${1:-} == --stills ]]; then
    film=${2:?a TMDB film id}; folder=${3:?a folder}
    mkdir -p "$folder"
    # Stills without words on them are the ones TMDB has with no language.
    tmdb "/movie/$film/images?include_image_language=null" \
        | python3 -I -c 'import json,sys; [print(b["file_path"], b["width"], b["height"], b.get("vote_average", 0)) for b in json.load(sys.stdin)["backdrops"]]' \
        | while read -r path w h vote; do
            curl -fsS --max-time 60 -o "$folder/${film}-${path#/}" "https://image.tmdb.org/t/p/w300$path"
            echo "$path ${w}x$h $vote"
        done
    exit 0
fi

again=
[[ ${1:-} == --again ]] && again=1
mkdir -p "$out"

for world in "${!grounds[@]}"; do
    n=0
    for one in ${grounds[$world]}; do
        n=$((n + 1))
        to="$out/$world-ground-$n.jpg"
        [[ -z $again && -s $to ]] && continue
        fetch "https://image.tmdb.org/t/p/original${one#*:}" "$to"
    done
done

for world in "${!mascots[@]}"; do
    to="$out/$world-mascot.jpg"
    [[ -z $again && -s $to ]] && continue
    media=${mascots[$world]%%:*}; name=${mascots[$world]#*:}
    query='query($id:Int){Media(id:$id){characters(perPage:50){nodes{name{full}image{large}}}}}'
    url=$(curl -fsS --max-time 30 -H 'Content-Type: application/json' \
        -d "{\"query\":\"$query\",\"variables\":{\"id\":$media}}" https://graphql.anilist.co \
        | python3 -I -c 'import json,sys; name=sys.argv[1]; nodes=json.load(sys.stdin)["data"]["Media"]["characters"]["nodes"]; print(next(n["image"]["large"] for n in nodes if n["name"]["full"] == name))' "$name")
    fetch "$url" "$to"
done
