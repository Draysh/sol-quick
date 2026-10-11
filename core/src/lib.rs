//! sol-quick-core: the half of sol-quick that needs no Qt. Everything a
//! world's logic uses from the kit lives here: the commands its screens call
//! (`Commands`, Undo), the desktop around the app (`desktop::Desktop`: the
//! bar's status, actions, the launcher's finds, quick capture), the
//! questions worlds ask each other and the door they go through, moments,
//! export and import, the shared engine slot, and the helpers for tests
//! (`testing`). The `sol-quick` crate re-exports all of it under the same
//! paths and adds the window (`sol_quick::run`, the QML module and the
//! `SolBackend` the screens talk to).
//!
//! A world keeps its logic in a crate of its own on this one alone
//! (`crates/<world>-core`, which names it `sol-quick` too, so the paths are
//! the kit's everywhere), so its tests build and run without Qt.

pub mod app;
#[doc(hidden)]
pub mod autostart;
pub mod capture;
pub mod commands;
pub mod desktop;
pub mod door;
pub mod engine;
pub mod exchange;
pub mod moments;
#[cfg(feature = "fake-navidrome")]
pub mod navidrome;
pub mod questions;
#[doc(hidden)]
pub mod seen;
#[doc(hidden)]
pub mod shared;
#[doc(hidden)]
pub mod single;
pub mod status;
pub mod testing;
#[doc(hidden)]
pub mod tray;
pub mod undo;

pub use app::{
    Prepare, Sample, World, cache_dir, data_dir, device_name, emit, leave, open, quit, runtime,
};
pub use commands::{Commands, doc, say};
pub use engine::{Shared, handler};
