//! sol-quick: the Sol design language as a Qt Quick module (`Sol.Design`),
//! and the Rust side every world's app shares: starting up, the one
//! QObject the screens talk to (`SolBackend`), and the commands they call.
//! Everything that needs no Qt (the commands, the desktop, questions,
//! doors, undo, moments, the test helpers) is `sol-quick-core` in `core/`,
//! re-exported here under the same paths; a world's logic crate uses that
//! one alone, so its tests never build Qt.
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

// Everything that needs no Qt, under the paths it always had
// (`sol_quick::desktop`, `sol_quick::testing`, …).
pub use sol_quick_core::*;

pub mod app;
pub mod bridge;
mod live;

pub use app::run;
