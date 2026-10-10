//! The stand-in's library: made-up artists, albums and tracks, the same on
//! every run (ids, play counts, stars and all), so a preview's pages and a
//! test's expectations can name them.

use std::{collections::BTreeMap, sync::OnceLock};

use super::Playlist;

#[derive(Debug, Clone, PartialEq)]
pub struct Artist {
    /// `ar-1` … `ar-9`; also its picture's cover id.
    pub id: String,
    pub name: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Album {
    /// `al-1` … `al-24`; also its cover id.
    pub id: String,
    pub name: String,
    pub artist: usize,
    pub year: u32,
    pub genre: String,
    /// When the server first saw it.
    pub created: String,
    pub songs: Vec<usize>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Song {
    /// `tr-<album>-<track>`.
    pub id: String,
    pub title: String,
    pub album: usize,
    pub track: u32,
    /// Seconds.
    pub duration: u32,
    pub plays: u64,
}

pub struct Library {
    pub artists: Vec<Artist>,
    pub albums: Vec<Album>,
    pub songs: Vec<Song>,
}

/// An artist, its genre, and its albums with their years.
type Discography = (&'static str, &'static str, &'static [(&'static str, u32)]);

/// Six artists with three albums and three with two (Triton's Discover
/// suggests those: artists like the ones you play, of whom you have little).
const ARTISTS: [Discography; 9] = [
    (
        "Marlow Reed",
        "Folk",
        &[
            ("Harbour Lights", 1971),
            ("Paper Boats", 1974),
            ("The Long Field", 1977),
        ],
    ),
    (
        "The Vesper Trio",
        "Jazz",
        &[
            ("Blue Hour", 1959),
            ("Late Set", 1963),
            ("Night Sketches", 1976),
        ],
    ),
    (
        "Ines Calder",
        "Soul",
        &[
            ("Sunday Kitchen", 1972),
            ("Warm Static", 1978),
            ("Porch Songs", 1983),
        ],
    ),
    (
        "Northbound Static",
        "Rock",
        &[
            ("Glass Coast", 1984),
            ("Signal Fires", 1988),
            ("Overpass", 1993),
        ],
    ),
    (
        "Kaito Mori",
        "Electronic",
        &[
            ("Neon Rain", 1996),
            ("Tidal Lines", 2003),
            ("Small Hours", 2011),
        ],
    ),
    (
        "Aster & Vale",
        "Ambient",
        &[("Slow Tides", 2012), ("Snowmelt", 2019)],
    ),
    (
        "Lumen Choir",
        "Folk",
        &[("Field Recordings", 2013), ("Hymns for Trains", 2015)],
    ),
    (
        "Juniper Hall",
        "Folk",
        &[("Low Orbit", 1979), ("Lantern", 2014)],
    ),
    (
        "Saffron Lane",
        "Soul",
        &[
            ("City Gardens", 2017),
            ("Afterglow", 2021),
            ("Open Windows", 2024),
        ],
    ),
];

const FIRST: [&str; 16] = [
    "Quiet", "Paper", "Golden", "Late", "Silver", "Hollow", "Northern", "Slow", "Little", "Open",
    "Blue", "Distant", "Bright", "Velvet", "Second", "Winter",
];
const SECOND: [&str; 16] = [
    "Harbour", "Lanterns", "Morning", "Rivers", "Static", "Gardens", "Letters", "Engines",
    "Weather", "Kitchen", "Station", "Tides", "Stairs", "Window", "Orchard", "Signals",
];

/// Tracks on every album.
const TRACKS: usize = 7;

/// A number from a few others, the same on every run (SplitMix64's mix).
pub(crate) fn hash(parts: &[u64]) -> u64 {
    let mut h: u64 = 0x9e37_79b9_7f4a_7c15;
    for p in parts {
        let mut z = h ^ p
            .wrapping_add(0x9e37_79b9_7f4a_7c15)
            .wrapping_mul(0xbf58_476d_1ce4_e5b9);
        z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
        h = z ^ (z >> 31);
    }
    h
}

impl Library {
    /// The one library, made the first time it is asked for.
    pub fn get() -> &'static Self {
        static LIBRARY: OnceLock<Library> = OnceLock::new();
        LIBRARY.get_or_init(Self::make)
    }

    fn make() -> Self {
        let mut artists = Vec::new();
        let mut albums = Vec::new();
        let mut songs = Vec::new();
        for (a, (name, genre, records)) in ARTISTS.iter().enumerate() {
            artists.push(Artist {
                id: format!("ar-{}", a + 1),
                name: (*name).into(),
            });
            for (title, year) in records.iter() {
                let n = albums.len();
                // Some records were never played: Discover has something to show.
                let never = hash(&[n as u64, 7]).is_multiple_of(4);
                let mut list = Vec::new();
                for t in 0..TRACKS {
                    let h = hash(&[n as u64, t as u64]);
                    // Every album's titles differ: the steps are prime to 16.
                    let words = (FIRST[(n * 5 + t * 3) % 16], SECOND[(n * 3 + t * 7) % 16]);
                    list.push(songs.len());
                    songs.push(Song {
                        id: format!("tr-{}-{}", n + 1, t + 1),
                        title: format!("{} {}", words.0, words.1),
                        album: n,
                        track: t as u32 + 1,
                        duration: 150 + (h >> 16) as u32 % 270,
                        plays: if never { 0 } else { (h >> 32) % 40 },
                    });
                }
                albums.push(Album {
                    id: format!("al-{}", n + 1),
                    name: (*title).into(),
                    artist: a,
                    year: *year,
                    genre: (*genre).into(),
                    created: format!(
                        "2025-{:02}-{:02}T20:{:02}:00Z",
                        1 + n % 12,
                        1 + (n * 7) % 27,
                        n % 60
                    ),
                    songs: list,
                });
            }
        }
        Self {
            artists,
            albums,
            songs,
        }
    }

    pub fn song(&self, id: &str) -> Option<&Song> {
        self.songs.iter().find(|s| s.id == id)
    }

    pub fn album(&self, id: &str) -> Option<&Album> {
        self.albums.iter().find(|a| a.id == id)
    }

    pub fn artist(&self, id: &str) -> Option<&Artist> {
        self.artists.iter().find(|a| a.id == id)
    }

    pub fn album_of(&self, song: &Song) -> &Album {
        &self.albums[song.album]
    }

    pub fn artist_of(&self, album: &Album) -> &Artist {
        &self.artists[album.artist]
    }

    /// An album's plays: its tracks' together.
    pub fn plays_of(&self, album: &Album) -> u64 {
        album.songs.iter().map(|&s| self.songs[s].plays).sum()
    }

    /// The genres, each with how many songs and albums are in it.
    pub fn genres(&self) -> Vec<(String, usize, usize)> {
        let mut by: BTreeMap<&str, (usize, usize)> = BTreeMap::new();
        for album in &self.albums {
            let e = by.entry(&album.genre).or_default();
            e.0 += album.songs.len();
            e.1 += 1;
        }
        by.into_iter()
            .map(|(g, (songs, albums))| (g.to_owned(), songs, albums))
            .collect()
    }

    /// The playlists there are when it starts.
    pub(crate) fn playlists(&self) -> Vec<Playlist> {
        let pick = |name: &str, comment: &str, n: usize, salt: u64| Playlist {
            id: format!("pl-{}", salt),
            name: name.into(),
            comment: comment.into(),
            songs: (0..n)
                .map(|i| {
                    let at = hash(&[salt, i as u64]) as usize % self.songs.len();
                    self.songs[at].id.clone()
                })
                .collect(),
            changed: "2025-09-14T19:30:00Z".into(),
        };
        vec![
            pick("Sunday morning", "Slow ones for the kitchen.", 10, 1),
            pick("Late night drive", "", 12, 2),
            pick("Rainy day", "Made in the preview.", 8, 3),
        ]
    }

    /// What is starred when it starts: a few songs, two albums, an artist.
    pub(crate) fn starred(&self) -> BTreeMap<String, String> {
        let at = "2025-08-02T21:00:00Z".to_owned();
        let mut out = BTreeMap::new();
        for s in self.songs.iter().step_by(13) {
            out.insert(s.id.clone(), at.clone());
        }
        for id in ["al-2", "al-17", "ar-3"] {
            out.insert(id.into(), at.clone());
        }
        out
    }
}
