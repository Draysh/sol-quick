#!/usr/bin/env bash
# The Yozora look's pictures, fetched for this computer only: each world's
# grounds (wide stills from a Makoto Shinkai film, from TMDB's image CDN)
# and its navigator (a character's portrait, from AniList's), into
# ~/.local/share/sol-yozora/ as <world>-ground-<n>.jpg and
# <world>-mascot.<jpg|png>. The pictures belong to their makers: they are
# never copied into a repository, a fixture or a release. Where they come
# from is core/yozora-art.json, the list every Sol app also reads to fetch
# what is missing when it starts; this script is for choosing new ones.
#
#   scripts/yozora-art.sh            fetch what is missing
#   scripts/yozora-art.sh --again    fetch every one again
#   scripts/yozora-art.sh --stills <tmdb-film-id> <folder>
#                                    small copies of every textless still of a
#                                    film, to choose grounds from (put the
#                                    chosen one's path in the list)
#   scripts/yozora-art.sh --portrait <anilist-media-id> <character's full name>
#                                    the address of a character's portrait,
#                                    for a mascot's `url` in the list
#
# Only --stills needs a TMDB key: Saturn's own (its settings in the
# installed app's local copy), or $TMDB_KEY; it is handed to curl on stdin,
# never printed or put on a command line. AniList needs no key.
set -euo pipefail

out=${SOL_YOZORA_DIR:-$HOME/.local/share/sol-yozora}
saturn_db=$HOME/.local/share/digital.sachi.sol.saturn/saturn.db
list=$(cd "$(dirname "$0")/.." && pwd)/core/yozora-art.json

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
    mv "$to.part" "$to"
    printf '%s\t%s\t%s\n' "$(basename "$to")" "$(du -h "$to" | cut -f1)" "$url"
}

if [[ ${1:-} == --portrait ]]; then
    media=${2:?an AniList media id}; name=${3:?the full name of the character}
    query='query($id:Int){Media(id:$id){characters(perPage:50){nodes{name{full}image{large}}}}}'
    curl -fsS --max-time 30 -H 'Content-Type: application/json' \
        -d "{\"query\":\"$query\",\"variables\":{\"id\":$media}}" https://graphql.anilist.co \
        | python3 -I -c 'import json,sys; name=sys.argv[1]; nodes=json.load(sys.stdin)["data"]["Media"]["characters"]["nodes"]; print(next(n["image"]["large"] for n in nodes if n["name"]["full"] == name))' "$name"
    exit 0
fi

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

# Every picture in the list, a line each: <file name> <address> (a mascot's name without its extension).
python3 -I - "$list" <<'PY' | while read -r name url; do
import json, sys
art = json.load(open(sys.argv[1]))
for world, grounds in art["grounds"].items():
    for n, g in enumerate(grounds, 1):
        print(f"{world}-ground-{n}.jpg https://image.tmdb.org/t/p/original{g['path']}")
for world, m in art["mascots"].items():
    print(f"{world}-mascot {m['url']}")
PY
    if [[ $name != *.jpg ]]; then
        # A portrait keeps the kind it comes as.
        [[ -z $again && ( -s $out/$name.jpg || -s $out/$name.png ) ]] && continue
        name=$name.${url##*.}
    fi
    [[ -z $again && -s $out/$name ]] && continue
    fetch "$url" "$out/$name"
done
