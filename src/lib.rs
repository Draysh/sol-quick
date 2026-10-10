//! sol-quick: the Sol design language as a Qt Quick module (`Sol.Design`),
//! and the Rust side every world's app shares: starting up, the one
//! QObject the screens talk to (`SolBackend`), and the commands they call.
//!
//! A world's `main.rs` is a few lines (`kit/template` has the whole of one):
//!
//! ```ignore
//! use std::sync::Arc;
//! use sol_quick::{Commands, World, say};
//!
//! fn main() {
//!     cxx_qt::init_crate!(sol_quick);
//!     cxx_qt::init_qml_module!("Sol.Design");
//!     let mut commands = Commands::default();
//!     commands.add("entries", |link, _: ()| async move { world::all(&link).await.map_err(say) });
//!     sol_quick::run(World {
//!         manifest: include_str!("../sol-world.json"),
//!         update_key: include_str!("../update.pub"),
//!         version: env!("CARGO_PKG_VERSION"),
//!         bin: env!("CARGO_PKG_NAME"),
//!         icons: &[(32, include_bytes!("../icons/32x32.png"))],
//!         handler: Arc::new(world::World),
//!         commands,
//!         main: "qrc:/qt/qml/Sol/Exoplanet/qml/Main.qml",
//!         sample: None,
//!         prepare: None,
//!         tray: &[],
//!         shortcuts: &[],
//!     })
//! }
//! ```

pub mod app;
mod autostart;
pub mod bridge;
pub mod commands;
pub mod desktop;
pub mod engine;
pub mod exchange;
#[cfg(feature = "fake-navidrome")]
pub mod navidrome;
mod seen;
mod shared;
mod single;
mod tray;

pub use app::{
    Prepare, Sample, World, cache_dir, data_dir, device_name, emit, leave, quit, run, runtime,
};
pub use commands::{Commands, say};
pub use engine::{Shared, handler};
