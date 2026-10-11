//! The stand-in over a real socket, as the worlds' clients reach it.

use std::io::{Read, Write};

use serde_json::Value;

use super::*;

/// A GET, answered as (status line, headers, body).
fn get(fake: &FakeNavidrome, path: &str, extra: &str) -> (String, String, Vec<u8>) {
    let addr = fake.url().trim_start_matches("http://");
    let mut s = std::net::TcpStream::connect(addr).unwrap();
    write!(s, "GET {path} HTTP/1.1\r\nHost: {addr}\r\n{extra}\r\n").unwrap();
    let mut all = Vec::new();
    s.read_to_end(&mut all).unwrap();
    let split = all.windows(4).position(|w| w == b"\r\n\r\n").unwrap();
    let head = String::from_utf8(all[..split].to_vec()).unwrap();
    let (status, headers) = head.split_once("\r\n").unwrap();
    (status.into(), headers.into(), all[split + 4..].to_vec())
}

fn call(fake: &FakeNavidrome, endpoint: &str, params: &str) -> Value {
    let path = format!("/rest/{endpoint}?u=me&t=x&s=y&v=1.16.1&c=test&f=json{params}");
    let body: Value = serde_json::from_slice(&get(fake, &path, "").2).unwrap();
    body["subsonic-response"].clone()
}

#[test]
fn it_answers_like_navidrome() {
    let fake = FakeNavidrome::start().unwrap();
    assert!(fake.url().starts_with("http://127.0.0.1:"));
    assert_eq!(call(&fake, "ping.view", "")["status"], "ok");
    let refused = &call(&fake, "ping", "").clone();
    assert_eq!(refused["status"], "ok", "any login, with or without .view");
    let lib = fake.library();
    assert_eq!(
        (lib.artists.len(), lib.albums.len(), lib.songs.len()),
        (11, 28, 181)
    );

    // Browsing: an album with its tracks, an artist with its albums.
    let album = &call(&fake, "getAlbum", "&id=al-1")["album"];
    assert_eq!(album["name"], "Harbour Lights");
    assert_eq!(album["artist"], "Marlow Reed");
    assert_eq!(album["song"].as_array().unwrap().len(), 7);
    assert_eq!(album["song"][0]["albumId"], "al-1");
    let artist = &call(&fake, "getArtist", "&id=ar-2")["artist"];
    assert_eq!(artist["album"].as_array().unwrap().len(), 3);
    let missing = call(&fake, "getAlbum", "&id=nope");
    assert_eq!(
        (
            missing["status"].as_str(),
            missing["error"]["code"].as_u64()
        ),
        (Some("failed"), Some(70))
    );

    // Lists, search, similar songs and a decade.
    let list = &call(
        &fake,
        "getAlbumList2",
        "&type=alphabeticalByName&size=500&offset=0",
    )["albumList2"]["album"];
    assert_eq!(list.as_array().unwrap().len(), 28);
    assert_eq!(list[0]["name"], "Afterglow");
    // The openings and endings, found by their show.
    let titan = &call(&fake, "search3", "&query=attack+on+titan&songCount=20")["searchResult3"];
    assert_eq!(titan["song"].as_array().unwrap().len(), 5);
    assert_eq!(titan["album"][0]["name"], "Attack on Titan Theme Songs");
    let seventies = &call(
        &fake,
        "getRandomSongs",
        "&size=500&fromYear=1970&toYear=1979",
    )["randomSongs"]["song"];
    assert_eq!(seventies.as_array().unwrap().len(), 7 * 7);
    let found = &call(&fake, "search3", "&query=vesper&songCount=5")["searchResult3"];
    assert_eq!(found["artist"][0]["name"], "The Vesper Trio");
    assert_eq!(found["song"].as_array().unwrap().len(), 5);
    let similar = &call(&fake, "getSimilarSongs2", "&id=tr-1-1&count=10")["similarSongs2"]["song"];
    assert!(
        similar
            .as_array()
            .unwrap()
            .iter()
            .all(|s| s["genre"] == "Folk" && s["albumId"] != "al-1")
    );
    let top = &call(&fake, "getTopSongs", "&artist=Ines+Calder&count=3")["topSongs"]["song"];
    assert_eq!(top.as_array().unwrap().len(), 3);
}

#[test]
fn playlists_and_stars_change_as_asked() {
    let fake = FakeNavidrome::start().unwrap();
    assert_eq!(fake.playlists().len(), 3);
    let made = &call(&fake, "createPlaylist", "&name=Triton%3A+Blue+radio")["playlist"];
    let id = made["id"].as_str().unwrap().to_owned();
    call(
        &fake,
        "updatePlaylist",
        &format!("&playlistId={id}&songIdToAdd=tr-1-1&songIdToAdd=tr-2-3&songIdToAdd=tr-3-1"),
    );
    call(
        &fake,
        "updatePlaylist",
        &format!("&playlistId={id}&songIndexToRemove=0&comment=Made"),
    );
    let held = fake.playlist("Triton: Blue radio").unwrap();
    assert_eq!(held.songs, ["tr-2-3", "tr-3-1"]);
    assert_eq!(held.comment, "Made");
    let listed = &call(&fake, "getPlaylist", &format!("&id={id}"))["playlist"];
    assert_eq!(listed["songCount"], 2);
    assert_eq!(listed["entry"][1]["id"], "tr-3-1");
    call(&fake, "deletePlaylist", &format!("&id={id}"));
    assert!(fake.playlist("Triton: Blue radio").is_none());

    call(&fake, "star", "&id=tr-4-4");
    let starred = &call(&fake, "getStarred2", "")["starred2"];
    assert!(
        starred["song"]
            .as_array()
            .unwrap()
            .iter()
            .any(|s| s["id"] == "tr-4-4")
    );
    assert_eq!(starred["album"].as_array().unwrap().len(), 2);
}

#[test]
fn covers_and_streams_are_real_files() {
    let fake = FakeNavidrome::start().unwrap();
    let (status, headers, png) = get(&fake, "/rest/getCoverArt?u=me&id=al-3", "");
    assert!(status.contains("200") && headers.contains("image/png"));
    assert_eq!(&png[..8], b"\x89PNG\r\n\x1a\n");
    assert_eq!(&png[12..16], b"IHDR");
    assert_ne!(
        png,
        get(&fake, "/rest/getCoverArt?u=me&id=al-4", "").2,
        "each its own"
    );

    let song = fake.library().song("tr-1-1").unwrap().duration;
    let (status, _, wav) = get(&fake, "/rest/stream.view?u=me&id=tr-1-1&format=raw", "");
    assert!(status.contains("200"));
    assert_eq!(&wav[..4], b"RIFF");
    assert_eq!(wav.len() as u64, 44 + u64::from(song) * 22_050);
    let (status, headers, tail) = get(
        &fake,
        "/rest/stream.view?u=me&id=tr-1-1",
        "Range: bytes=-4096\r\n",
    );
    assert!(status.contains("206") && headers.contains("Content-Range: bytes "));
    assert_eq!(tail.len(), 4096);
}
