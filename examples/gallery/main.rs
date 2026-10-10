//! The kit's gallery: every part of `Sol.Design` on four pages, in the
//! kit's own window, so a change to the kit can be seen with one build
//! (`cargo run --example gallery`, or `scripts/gallery-shots.sh` for the
//! pictures). It runs as a preview with no Sol and no network: the Shell
//! opens at once, never the Connect screen.
//!
//! An example, not part of the library: the worlds get nothing from it.
//! Its own screens (`examples/gallery/qml/`) are read from this checkout
//! when it starts, so a change to them needs no build at all; the kit's
//! QML is the compiled module, as in a world.

use std::sync::Arc;

use sol_quick::{Commands, World};

const MANIFEST: &str = r#"{
  "id": "gallery",
  "name": "Gallery",
  "tagline": "Every part of the Sol design kit, on four pages",
  "role": "The kit at a glance",
  "repo": "Draysh/sol-quick"
}"#;

fn main() {
    cxx_qt::init_crate!(sol_quick);
    cxx_qt::init_qml_module!("Sol.Design");

    // Always a preview: the Shell without pairing, on a throwaway copy
    // (`/tmp/sol-preview-gallery`), beside any world that is running.
    if std::env::var_os("SOL_PREVIEW").is_none() {
        // SAFETY: nothing else runs yet; the kit reads it from here on.
        unsafe { std::env::set_var("SOL_PREVIEW", "1") };
    }

    sol_quick::run(World {
        manifest: MANIFEST,
        update_key: "",
        version: env!("CARGO_PKG_VERSION"),
        bin: "sol-gallery",
        icons: &[(64, include_bytes!("../../assets/sol-tray.png"))],
        handler: Arc::new(orbit::link::Ignore),
        commands: Commands::default(),
        main: concat!(
            "file://",
            env!("CARGO_MANIFEST_DIR"),
            "/examples/gallery/qml/Main.qml"
        ),
        sample: None,
        prepare: None,
        tray: &[],
        shortcuts: &[],
    })
}
