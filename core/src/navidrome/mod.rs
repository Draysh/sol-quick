//! A stand-in Navidrome for the previews of the music worlds (Neptune and
//! Triton) and for their tests: a made-up library of 11 artists, 28 albums
//! and 181 tracks (13 of them anime openings and endings), naming no
//! covers (the apps show their card for missing art), three playlists, starred
//! things, play counts, similar songs and lyrics, served over the part of
//! the Subsonic API those worlds ask for. Streams are silence of each
//! track's length; a cover asked for by id is a drawn PNG. It listens on 127.0.0.1 only, at
//! a port of its own, and ends with the app. Behind the `fake-navidrome`
//! feature.
//!
//! ```ignore
//! // In a world's configure: no login in Sol, and a preview.
//! if let Some(fake) = sol_quick::navidrome::preview() {
//!     let (url, user, password) = fake.login();
//! }
//! ```

mod api;
mod http;
mod library;
mod media;

use std::{
    collections::BTreeMap,
    net::TcpListener,
    sync::{Arc, Mutex, OnceLock},
};

pub use library::{Album, Artist, Library, Song};

/// The login it takes (any other is taken too).
pub const USER: &str = "preview";
pub const PASSWORD: &str = "preview";

/// A playlist as the stand-in keeps it.
#[derive(Debug, Clone, PartialEq)]
pub struct Playlist {
    pub id: String,
    pub name: String,
    pub comment: String,
    pub songs: Vec<String>,
    /// When it last changed, as Navidrome writes it.
    pub changed: String,
}

/// What changes while it runs: playlists, stars and plays.
#[derive(Debug)]
pub(crate) struct State {
    pub playlists: Vec<Playlist>,
    /// Ids of starred songs, albums and artists, with when.
    pub starred: BTreeMap<String, String>,
    /// Plays scrobbled since it started, by song id.
    pub plays: BTreeMap<String, u64>,
    /// Numbers playlist ids and turns the random songs.
    pub counter: u64,
}

/// A stand-in Navidrome, serving until the app ends.
#[derive(Clone)]
pub struct FakeNavidrome {
    url: String,
    library: &'static Library,
    state: Arc<Mutex<State>>,
}

impl FakeNavidrome {
    /// Starts one on 127.0.0.1, at a port the system picks.
    pub fn start() -> std::io::Result<Self> {
        let listener = TcpListener::bind("127.0.0.1:0")?;
        let url = format!("http://{}", listener.local_addr()?);
        let library = Library::get();
        let state = Arc::new(Mutex::new(State {
            playlists: library.playlists(),
            starred: library.starred(),
            plays: BTreeMap::new(),
            counter: 0,
        }));
        let fake = Self {
            url,
            library,
            state,
        };
        let serving = fake.clone();
        std::thread::Builder::new()
            .name("fake-navidrome".into())
            .spawn(move || http::serve(listener, &serving))?;
        Ok(fake)
    }

    /// Where it answers, `http://127.0.0.1:<port>`.
    pub fn url(&self) -> &str {
        &self.url
    }

    /// The address, user and password to sign in with.
    pub fn login(&self) -> (String, String, String) {
        (self.url.clone(), USER.into(), PASSWORD.into())
    }

    /// The library it serves (the same every time).
    pub fn library(&self) -> &'static Library {
        self.library
    }

    /// A playlist by name, as it stands now: what a test checks.
    pub fn playlist(&self, name: &str) -> Option<Playlist> {
        self.state()
            .playlists
            .iter()
            .find(|p| p.name == name)
            .cloned()
    }

    /// Every playlist, as it stands now.
    pub fn playlists(&self) -> Vec<Playlist> {
        self.state().playlists.clone()
    }

    fn state(&self) -> std::sync::MutexGuard<'_, State> {
        self.state.lock().expect("fake Navidrome state")
    }
}

/// The stand-in for this preview, started the first time it is asked for:
/// only under `SOL_PREVIEW`, and not when `SOL_FAKE_NAVIDROME=off` (to look
/// at the pages without a Navidrome).
pub fn preview() -> Option<&'static FakeNavidrome> {
    static FAKE: OnceLock<Option<FakeNavidrome>> = OnceLock::new();
    FAKE.get_or_init(|| {
        let wanted = std::env::var_os("SOL_PREVIEW").is_some()
            && std::env::var("SOL_FAKE_NAVIDROME").as_deref() != Ok("off");
        if !wanted {
            return None;
        }
        match FakeNavidrome::start() {
            Ok(fake) => {
                tracing::info!(url = fake.url(), "a stand-in Navidrome for the preview");
                Some(fake)
            }
            Err(e) => {
                tracing::warn!("couldn't start the stand-in Navidrome: {e}");
                None
            }
        }
    })
    .as_ref()
}

#[cfg(test)]
mod tests;
