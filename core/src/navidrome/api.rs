//! The Subsonic endpoints the stand-in answers, in Navidrome's JSON shapes:
//! browsing, lists, search, similar and top songs, stars, playlists,
//! scrobbles and lyrics. Any login is taken.

use serde_json::{Map, Value, json};

use super::{
    FakeNavidrome, Playlist, State,
    library::{Album, Artist, Library, Song, hash},
    media::Silence,
};

type Answer = Result<Value, (u32, String)>;

/// The query's values for a key, in order (a key may come many times).
struct Params<'a>(&'a [(String, String)]);

impl Params<'_> {
    fn get(&self, key: &str) -> Option<&str> {
        self.0
            .iter()
            .find(|(k, _)| k == key)
            .map(|(_, v)| v.as_str())
    }

    fn all(&self, key: &str) -> Vec<&str> {
        self.0
            .iter()
            .filter(|(k, _)| k == key)
            .map(|(_, v)| v.as_str())
            .collect()
    }

    fn number(&self, key: &str, or: usize) -> usize {
        self.get(key).and_then(|v| v.parse().ok()).unwrap_or(or)
    }

    fn need(&self, key: &str) -> Result<&str, (u32, String)> {
        self.get(key)
            .filter(|v| !v.is_empty())
            .ok_or((10, format!("Required parameter '{key}' is missing")))
    }
}

/// One endpoint's whole answer, `subsonic-response` and all.
pub fn answer(fake: &FakeNavidrome, endpoint: &str, query: &[(String, String)]) -> Value {
    let p = Params(query);
    let mut state = fake.state();
    let answered = if p.get("u").is_none_or(str::is_empty) {
        Err((10, "Required parameter 'u' is missing".into()))
    } else {
        reply(fake.library, &mut state, endpoint, &p)
    };
    let mut inner = Map::new();
    inner.insert("version".into(), "1.16.1".into());
    inner.insert("type".into(), "navidrome".into());
    inner.insert("serverVersion".into(), "0.58.0 (preview)".into());
    inner.insert("openSubsonic".into(), true.into());
    match answered {
        Ok(Value::Object(payload)) => {
            inner.insert("status".into(), "ok".into());
            inner.extend(payload);
        }
        Ok(_) => {
            inner.insert("status".into(), "ok".into());
        }
        Err((code, message)) => {
            inner.insert("status".into(), "failed".into());
            inner.insert("error".into(), json!({ "code": code, "message": message }));
        }
    }
    json!({ "subsonic-response": inner })
}

fn not_found(what: &str) -> (u32, String) {
    (70, format!("{what} not found"))
}

fn reply(lib: &Library, st: &mut State, endpoint: &str, p: &Params) -> Answer {
    let one = |v: Value| -> Answer { Ok(v) };
    match endpoint {
        "ping" | "getLicense" | "getScanStatus" => one(json!({})),
        "getArtists" | "getIndexes" => {
            let mut index: Vec<(String, Vec<Value>)> = Vec::new();
            let mut artists: Vec<&Artist> = lib.artists.iter().collect();
            artists.sort_by_key(|a| a.name.to_lowercase());
            for a in artists {
                let letter = a.name[..1].to_uppercase();
                match index.last_mut() {
                    Some((l, list)) if *l == letter => list.push(artist(lib, st, a)),
                    _ => index.push((letter, vec![artist(lib, st, a)])),
                }
            }
            let index: Vec<Value> = index
                .into_iter()
                .map(|(name, artist)| json!({ "name": name, "artist": artist }))
                .collect();
            one(json!({ "artists": { "ignoredArticles": "The", "index": index } }))
        }
        "getArtist" => {
            let a = lib
                .artist(p.need("id")?)
                .ok_or_else(|| not_found("Artist"))?;
            let mut v = artist(lib, st, a);
            v["album"] = albums_of(lib, st, a).into();
            one(json!({ "artist": v }))
        }
        "getArtistInfo2" | "getArtistInfo" => {
            let a = lib
                .artist(p.need("id")?)
                .ok_or_else(|| not_found("Artist"))?;
            let genre = &lib.albums[lib
                .albums
                .iter()
                .position(|al| lib.artist_of(al) == a)
                .unwrap_or(0)]
            .genre;
            let mut kin: Vec<&Artist> = lib.artists.iter().filter(|b| *b != a).collect();
            kin.sort_by_key(|b| {
                let same = lib
                    .albums
                    .iter()
                    .any(|al| lib.artist_of(al) == *b && &al.genre == genre);
                (!same, hash(&[b.id.len() as u64, b.name.len() as u64]))
            });
            let similar: Vec<Value> = kin
                .into_iter()
                .take(p.number("count", 20))
                .map(|b| artist(lib, st, b))
                .collect();
            let key = if endpoint == "getArtistInfo" {
                "artistInfo"
            } else {
                "artistInfo2"
            };
            one(json!({ key: {
                "biography": format!("{} is an artist made up for Sol's previews.", a.name),
                "similarArtist": similar,
            } }))
        }
        "getAlbum" => {
            let a = lib.album(p.need("id")?).ok_or_else(|| not_found("Album"))?;
            one(json!({ "album": album(lib, st, a, true) }))
        }
        "getAlbumList2" | "getAlbumList" => {
            let list = album_list(lib, st, p)?;
            let key = if endpoint == "getAlbumList" {
                "albumList"
            } else {
                "albumList2"
            };
            one(json!({ key: { "album": list } }))
        }
        "getSong" => {
            let s = lib.song(p.need("id")?).ok_or_else(|| not_found("Song"))?;
            one(json!({ "song": song(lib, st, s) }))
        }
        "getRandomSongs" => {
            st.counter += 1;
            let turn = st.counter;
            let genre = p.get("genre");
            let years = (
                p.get("fromYear").and_then(|y| y.parse().ok()),
                p.get("toYear").and_then(|y| y.parse().ok()),
            );
            let mut found: Vec<&Song> = lib
                .songs
                .iter()
                .filter(|s| {
                    let al = lib.album_of(s);
                    genre.is_none_or(|g| g.eq_ignore_ascii_case(&al.genre))
                        && years.0.is_none_or(|y: u32| al.year >= y)
                        && years.1.is_none_or(|y: u32| al.year <= y)
                })
                .collect();
            found.sort_by_key(|s| hash(&[turn, s.album as u64, u64::from(s.track)]));
            let songs: Vec<Value> = found
                .iter()
                .take(p.number("size", 10).min(500))
                .map(|s| song(lib, st, s))
                .collect();
            one(json!({ "randomSongs": { "song": songs } }))
        }
        "getSongsByGenre" => {
            let genre = p.need("genre")?;
            let songs: Vec<Value> = lib
                .songs
                .iter()
                .filter(|s| lib.album_of(s).genre.eq_ignore_ascii_case(genre))
                .skip(p.number("offset", 0))
                .take(p.number("count", 10).min(500))
                .map(|s| song(lib, st, s))
                .collect();
            one(json!({ "songsByGenre": { "song": songs } }))
        }
        "getSimilarSongs2" | "getSimilarSongs" => {
            let seed = lib.song(p.need("id")?).ok_or_else(|| not_found("Song"))?;
            let genre = &lib.album_of(seed).genre;
            let mut like: Vec<&Song> = lib
                .songs
                .iter()
                .filter(|s| s.album != seed.album && &lib.album_of(s).genre == genre)
                .collect();
            like.sort_by_key(|s| hash(&[seed.album as u64, s.album as u64, u64::from(s.track)]));
            let songs: Vec<Value> = like
                .iter()
                .take(p.number("count", 50))
                .map(|s| song(lib, st, s))
                .collect();
            let key = if endpoint == "getSimilarSongs" {
                "similarSongs"
            } else {
                "similarSongs2"
            };
            one(json!({ key: { "song": songs } }))
        }
        "getTopSongs" => {
            let name = p.need("artist")?;
            let mut theirs: Vec<&Song> = lib
                .songs
                .iter()
                .filter(|s| {
                    lib.artist_of(lib.album_of(s))
                        .name
                        .eq_ignore_ascii_case(name)
                })
                .collect();
            theirs.sort_by_key(|s| std::cmp::Reverse(plays(st, s)));
            let songs: Vec<Value> = theirs
                .iter()
                .take(p.number("count", 50))
                .map(|s| song(lib, st, s))
                .collect();
            one(json!({ "topSongs": { "song": songs } }))
        }
        "getStarred2" | "getStarred" => {
            let starred = |id: &str| st.starred.contains_key(id);
            let songs: Vec<Value> = lib
                .songs
                .iter()
                .filter(|s| starred(&s.id))
                .map(|s| song(lib, st, s))
                .collect();
            let albums: Vec<Value> = lib
                .albums
                .iter()
                .filter(|a| starred(&a.id))
                .map(|a| album(lib, st, a, false))
                .collect();
            let artists: Vec<Value> = lib
                .artists
                .iter()
                .filter(|a| starred(&a.id))
                .map(|a| artist(lib, st, a))
                .collect();
            let key = if endpoint == "getStarred" {
                "starred"
            } else {
                "starred2"
            };
            one(json!({ key: { "song": songs, "album": albums, "artist": artists } }))
        }
        "star" | "unstar" => {
            let ids: Vec<String> = ["id", "albumId", "artistId"]
                .iter()
                .flat_map(|k| p.all(k))
                .map(str::to_owned)
                .collect();
            for id in ids {
                if endpoint == "star" {
                    st.starred.insert(id, "2026-10-10T20:00:00Z".into());
                } else {
                    st.starred.remove(&id);
                }
            }
            one(json!({}))
        }
        "getGenres" => {
            let genres: Vec<Value> = lib
                .genres()
                .into_iter()
                .map(|(value, songs, albums)| json!({ "value": value, "songCount": songs, "albumCount": albums }))
                .collect();
            one(json!({ "genres": { "genre": genres } }))
        }
        "search3" | "search2" => {
            let q = p
                .get("query")
                .unwrap_or_default()
                .trim_matches('"')
                .to_lowercase();
            let has = |text: &str| q.is_empty() || text.to_lowercase().contains(&q);
            let page = |kind: &str| {
                (
                    p.number(&format!("{kind}Offset"), 0),
                    p.number(&format!("{kind}Count"), 20),
                )
            };
            let (ao, an) = page("artist");
            let (bo, bn) = page("album");
            let (so, sn) = page("song");
            let artists: Vec<Value> = lib
                .artists
                .iter()
                .filter(|a| has(&a.name))
                .skip(ao)
                .take(an)
                .map(|a| artist(lib, st, a))
                .collect();
            let albums: Vec<Value> = lib
                .albums
                .iter()
                .filter(|a| has(&a.name) || has(&lib.artist_of(a).name))
                .skip(bo)
                .take(bn)
                .map(|a| album(lib, st, a, false))
                .collect();
            let songs: Vec<Value> = lib
                .songs
                .iter()
                .filter(|s| {
                    has(&s.title)
                        || has(&lib.album_of(s).name)
                        || has(&lib.artist_of(lib.album_of(s)).name)
                })
                .skip(so)
                .take(sn)
                .map(|s| song(lib, st, s))
                .collect();
            let key = if endpoint == "search2" {
                "searchResult2"
            } else {
                "searchResult3"
            };
            one(json!({ key: { "artist": artists, "album": albums, "song": songs } }))
        }
        "getPlaylists" => {
            let lists: Vec<Value> = st
                .playlists
                .iter()
                .map(|pl| playlist(lib, st, pl, false))
                .collect();
            one(json!({ "playlists": { "playlist": lists } }))
        }
        "getPlaylist" => {
            let id = p.need("id")?;
            let pl = st
                .playlists
                .iter()
                .find(|pl| pl.id == id)
                .ok_or_else(|| not_found("Playlist"))?;
            one(json!({ "playlist": playlist(lib, st, pl, true) }))
        }
        "createPlaylist" => {
            let songs: Vec<String> = p
                .all("songId")
                .into_iter()
                .filter(|id| lib.song(id).is_some())
                .map(str::to_owned)
                .collect();
            let at = if let Some(id) = p.get("playlistId") {
                let at = st
                    .playlists
                    .iter()
                    .position(|pl| pl.id == id)
                    .ok_or_else(|| not_found("Playlist"))?;
                st.playlists[at].songs = songs;
                at
            } else {
                st.counter += 1;
                let id = format!("pl-new-{}", st.counter);
                st.playlists.push(Playlist {
                    id,
                    name: p.need("name")?.to_owned(),
                    comment: String::new(),
                    songs,
                    changed: String::new(),
                });
                st.playlists.len() - 1
            };
            st.playlists[at].changed = changed(st.counter);
            one(json!({ "playlist": playlist(lib, st, &st.playlists[at], true) }))
        }
        "updatePlaylist" => {
            let id = p.need("playlistId")?;
            let at = st
                .playlists
                .iter()
                .position(|pl| pl.id == id)
                .ok_or_else(|| not_found("Playlist"))?;
            st.counter += 1;
            let stamp = changed(st.counter);
            let pl = &mut st.playlists[at];
            if let Some(name) = p.get("name") {
                pl.name = name.to_owned();
            }
            if let Some(comment) = p.get("comment") {
                pl.comment = comment.to_owned();
            }
            let mut gone: Vec<usize> = p
                .all("songIndexToRemove")
                .iter()
                .filter_map(|i| i.parse().ok())
                .collect();
            gone.sort_unstable();
            gone.dedup();
            for i in gone.into_iter().rev() {
                if i < pl.songs.len() {
                    pl.songs.remove(i);
                }
            }
            pl.songs.extend(
                p.all("songIdToAdd")
                    .into_iter()
                    .filter(|id| lib.song(id).is_some())
                    .map(str::to_owned),
            );
            pl.changed = stamp;
            one(json!({}))
        }
        "deletePlaylist" => {
            let id = p.need("id")?;
            let before = st.playlists.len();
            st.playlists.retain(|pl| pl.id != id);
            if st.playlists.len() == before {
                return Err(not_found("Playlist"));
            }
            one(json!({}))
        }
        "scrobble" => {
            if p.get("submission") != Some("false") {
                for id in p.all("id") {
                    *st.plays.entry(id.to_owned()).or_default() += 1;
                }
            }
            one(json!({}))
        }
        "getNowPlaying" => one(json!({ "nowPlaying": {} })),
        "getLyricsBySongId" => {
            let s = lib.song(p.need("id")?).ok_or_else(|| not_found("Song"))?;
            let sets: Vec<Value> = words(lib, s)
                .map(|lines| {
                    let line: Vec<Value> = lines
                        .iter()
                        .enumerate()
                        .map(|(i, l)| json!({ "start": 4_000 + i as u64 * 6_500, "value": l }))
                        .collect();
                    vec![json!({ "lang": if lines[0] == JAPANESE[0] { "jpn" } else { "eng" }, "synced": true, "offset": 0, "line": line,
                                 "displayArtist": lib.artist_of(lib.album_of(s)).name, "displayTitle": s.title })]
                })
                .unwrap_or_default();
            one(json!({ "lyricsList": { "structuredLyrics": sets } }))
        }
        "getLyrics" => {
            let (artist, title) = (
                p.get("artist").unwrap_or_default(),
                p.get("title").unwrap_or_default(),
            );
            let found = lib.songs.iter().find(|s| {
                s.title.eq_ignore_ascii_case(title)
                    && lib
                        .artist_of(lib.album_of(s))
                        .name
                        .eq_ignore_ascii_case(artist)
            });
            one(match found.and_then(|s| words(lib, s)) {
                Some(lines) => {
                    json!({ "lyrics": { "artist": artist, "title": title, "value": lines.join("\n") } })
                }
                None => json!({ "lyrics": {} }),
            })
        }
        other => Err((0, format!("the preview's Navidrome doesn't do {other}"))),
    }
}

/// When a playlist changed: a stamp that moves with every edit.
fn changed(n: u64) -> String {
    format!("2026-10-10T20:{:02}:{:02}Z", n / 60 % 60, n % 60)
}

fn plays(st: &State, s: &Song) -> u64 {
    s.plays + st.plays.get(&s.id).copied().unwrap_or(0)
}

/// Every album's first track has words (made up, synced every few seconds).
/// Kaito Mori sings in Japanese: his first tracks have these words (our
/// own), so a preview can show the lyrics with readings over the kanji.
const JAPANESE: [&str; 6] = [
    "夜の街を一人で歩いて",
    "君の声をずっと探している",
    "雨が降っても大丈夫だよ",
    "明日はきっと晴れるから",
    "小さな光を見つけた",
    "一緒にもう一度歌おう",
];

fn words(lib: &Library, s: &Song) -> Option<Vec<String>> {
    (s.track == 1).then(|| {
        let album = &lib.album_of(s).name;
        if lib.artist_of(lib.album_of(s)).name == "Kaito Mori" {
            return JAPANESE.iter().map(|l| (*l).to_owned()).collect();
        }
        vec![
            format!("We left the lights on in {album}"),
            "and the radio kept the time".into(),
            format!("{} all the way home", s.title.to_lowercase()),
            "nobody asked where we were going".into(),
            "the night was long enough for both".into(),
            "so we sang it once again".into(),
        ]
    })
}

fn starred(st: &State, id: &str, v: &mut Value) {
    if let Some(at) = st.starred.get(id) {
        v["starred"] = at.clone().into();
    }
}

fn artist(lib: &Library, st: &State, a: &Artist) -> Value {
    let albums = lib
        .albums
        .iter()
        .filter(|al| lib.artist_of(al) == a)
        .count();
    let mut v = json!({ "id": a.id, "name": a.name, "albumCount": albums,
                        "artistImageUrl": "" });
    starred(st, &a.id, &mut v);
    v
}

fn albums_of(lib: &Library, st: &State, a: &Artist) -> Vec<Value> {
    lib.albums
        .iter()
        .filter(|al| lib.artist_of(al) == a)
        .map(|al| album(lib, st, al, false))
        .collect()
}

fn album(lib: &Library, st: &State, a: &Album, with_songs: bool) -> Value {
    let artist = lib.artist_of(a);
    let duration: u32 = a.songs.iter().map(|&s| lib.songs[s].duration).sum();
    let played: u64 = a.songs.iter().map(|&s| plays(st, &lib.songs[s])).sum();
    let mut v = json!({
        "id": a.id, "name": a.name, "title": a.name, "album": a.name, "artist": artist.name,
        "artistId": artist.id, "songCount": a.songs.len(), "duration": duration,
        "created": a.created, "year": a.year, "genre": a.genre, "isDir": true,
    });
    if played > 0 {
        v["playCount"] = played.into();
    }
    starred(st, &a.id, &mut v);
    if with_songs {
        v["song"] = a
            .songs
            .iter()
            .map(|&s| song(lib, st, &lib.songs[s]))
            .collect::<Vec<_>>()
            .into();
    }
    v
}

fn song(lib: &Library, st: &State, s: &Song) -> Value {
    let album = lib.album_of(s);
    let artist = lib.artist_of(album);
    let mut v = json!({
        "id": s.id, "parent": album.id, "isDir": false, "title": s.title, "album": album.name,
        "artist": artist.name, "track": s.track, "discNumber": 1, "year": album.year,
        "genre": album.genre, "size": Silence::new(s.duration).len,
        "contentType": "audio/wav", "suffix": "wav", "duration": s.duration,
        "bitRate": Silence::kbps(), "path": format!("{}/{}/{:02} {}.wav", artist.name, album.name, s.track, s.title),
        "created": album.created, "albumId": album.id, "artistId": artist.id, "type": "music",
        "isVideo": false, "playCount": plays(st, s),
    });
    starred(st, &s.id, &mut v);
    v
}

fn playlist(lib: &Library, st: &State, pl: &Playlist, with_entries: bool) -> Value {
    let songs: Vec<&Song> = pl.songs.iter().filter_map(|id| lib.song(id)).collect();
    let mut v = json!({
        "id": pl.id, "name": pl.name, "comment": pl.comment, "owner": super::USER, "public": false,
        "songCount": songs.len(), "duration": songs.iter().map(|s| s.duration).sum::<u32>(),
        "created": "2025-09-01T18:00:00Z", "changed": pl.changed,
    });
    if with_entries {
        v["entry"] = songs
            .iter()
            .map(|s| song(lib, st, s))
            .collect::<Vec<_>>()
            .into();
    }
    v
}

/// `getAlbumList2`'s orderings.
fn album_list(lib: &Library, st: &mut State, p: &Params) -> Result<Vec<Value>, (u32, String)> {
    let kind = p.need("type")?;
    let mut list: Vec<&Album> = lib.albums.iter().collect();
    let played = |a: &Album| {
        a.songs
            .iter()
            .map(|&s| plays(st, &lib.songs[s]))
            .sum::<u64>()
    };
    match kind {
        "alphabeticalByName" => list.sort_by_key(|a| a.name.to_lowercase()),
        "alphabeticalByArtist" => {
            list.sort_by_key(|a| (lib.artist_of(a).name.to_lowercase(), a.year))
        }
        "newest" => list.sort_by(|a, b| b.created.cmp(&a.created)),
        "frequent" | "highest" => {
            list.retain(|a| played(a) > 0);
            list.sort_by_key(|a| std::cmp::Reverse(played(a)));
        }
        "recent" => {
            list.retain(|a| played(a) > 0);
            list.sort_by_key(|a| hash(&[a.year.into(), 3]));
        }
        "random" => {
            st.counter += 1;
            let turn = st.counter;
            list.sort_by_key(|a| hash(&[turn, a.year.into(), a.songs[0] as u64]));
        }
        "starred" => list.retain(|a| st.starred.contains_key(&a.id)),
        "byYear" => {
            let year = |k: &str| p.get(k).and_then(|y| y.parse::<u32>().ok());
            let (from, to) = (
                year("fromYear").unwrap_or(0),
                year("toYear").unwrap_or(9999),
            );
            let (lo, hi) = (from.min(to), from.max(to));
            list.retain(|a| (lo..=hi).contains(&a.year));
            list.sort_by_key(|a| a.year);
            if from > to {
                list.reverse();
            }
        }
        "byGenre" => {
            let genre = p.need("genre")?;
            list.retain(|a| a.genre.eq_ignore_ascii_case(genre));
        }
        other => return Err((0, format!("no such list type: {other}"))),
    }
    let (offset, size) = (p.number("offset", 0), p.number("size", 10).min(500));
    Ok(list
        .into_iter()
        .skip(offset)
        .take(size)
        .map(|a| album(lib, st, a, false))
        .collect())
}
