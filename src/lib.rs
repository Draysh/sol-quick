//! sol-quick: the Sol design language as a Qt Quick module (`Sol.Design`),
//! and the Rust side every world's app shares: starting up, the one
//! QObject the screens talk to (`SolBackend`), and the commands they call.
//!
//! A world's `main.rs` is a few lines (`kit/template` has the whole of one):
//!
//! ```ignore
//! use std::sync::Arc;
//! use sol_quick::World;
//!
//! fn main() {
//!     cxx_qt::init_crate!(sol_quick);
//!     cxx_qt::init_qml_module!("Sol.Design");
//!     sol_quick::run(World {
//!         manifest: include_str!("../sol-world.json"),
//!         update_key: include_str!("../update.pub"),
//!         version: env!("CARGO_PKG_VERSION"),
//!         bin: env!("CARGO_PKG_NAME"),
//!         icons: &[(32, include_bytes!("../icons/32x32.png"))],
//!         handler: Arc::new(world::World),
//!         // Each module registers its own (`world::commands()`).
//!         commands: world::commands(),
//!         main: "qrc:/qt/qml/Sol/Exoplanet/qml/Main.qml",
//!         source: env!("CARGO_MANIFEST_DIR"),
//!         sample: Some(Arc::new(|link| Box::pin(world::sample::fill(link)))),
//!         prepare: None,
//!         tray: &[],
//!         shortcuts: &[],
//!     })
//! }
//! ```

pub mod app;
mod autostart;
pub mod bridge;
pub mod capture;
pub mod commands;
pub mod desktop;
pub mod door;
pub mod engine;
pub mod exchange;
mod live;
pub mod moments;
#[cfg(feature = "fake-navidrome")]
pub mod navidrome;
pub mod questions;
mod seen;
mod shared;
mod single;
pub mod status;
#[cfg(feature = "testing")]
pub mod testing;
mod tray;
pub mod undo;

pub use app::{
    Prepare, Sample, World, cache_dir, data_dir, device_name, emit, leave, open, quit, run, runtime,
};
pub use commands::{Commands, doc, say};
pub use engine::{Shared, handler};
