//! sol-quick: the Sol design language as a Qt Quick module (`Sol.Design`),
//! and the Rust side every world's app shares: starting up, the one
//! QObject the screens talk to (`SolBackend`), and the commands they call.
//!
//! A world's `main.rs` is a few lines:
//!
//! ```ignore
//! fn main() {
//!     cxx_qt::init_crate!(sol_quick);
//!     let mut commands = sol_quick::Commands::default();
//!     commands.add("entries", |link, _: ()| async move { world::all(&link).await.map_err(say) });
//!     sol_quick::run(sol_quick::World {
//!         manifest: include_str!("../sol-world.json"),
//!         update_key: include_str!("../update.pub"),
//!         version: env!("CARGO_PKG_VERSION"),
//!         bin: env!("CARGO_PKG_NAME"),
//!         icons: &[(32, include_bytes!("../icons/32x32.png"))],
//!         handler: Arc::new(world::World),
//!         commands,
//!         main: "qrc:/qt/qml/Sol/Exoplanet/qml/Main.qml",
//!     })
//! }
//! ```

pub mod app;
pub mod bridge;
pub mod commands;
pub mod desktop;
mod single;

pub use app::{Prepare, Sample, World, data_dir, emit, leave, run, runtime};
pub use commands::{Commands, say};
