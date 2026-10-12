//! The kit's gallery: every part of `Sol.Design` on five pages, in the
//! kit's own window, so a change to the kit can be seen with one build
//! (`cargo run --example gallery`, or `scripts/gallery-shots.sh` for the
//! pictures). It runs as a preview with no Sol and no network: the Shell
//! opens at once, never the Connect screen.
//!
//! An example, not part of the library: the worlds get nothing from it.
//! Its own screens (`examples/gallery/qml/`) are read from this checkout
//! when it starts, so a change to them needs no build at all; the kit's
//! QML is the compiled module, as in a world, unless `SOL_QML_LIVE=1`
//! reads it from this checkout too (`scripts/gallery-shots.sh` does).

use std::sync::Arc;

use sol_quick::{
    Commands, Moon, World,
    desktop::{Desktop, Plan, Typed},
    sky::{self, Constellation},
};

const MANIFEST: &str = r#"{
  "id": "gallery",
  "name": "Gallery",
  "tagline": "Every part of the Sol design kit, on five pages",
  "role": "The kit at a glance",
  "repo": "Draysh/sol-quick"
}"#;

/// A sky as a world would have one: some stars lit, some still to come.
fn sky() -> Vec<Constellation> {
    let count = |n: u64, at: &[u64], thing: &'static str, id: &str, title: &str| {
        Constellation::new(
            id,
            title,
            &format!(
                "{}{} kept, a star at each step.",
                thing[..1].to_uppercase(),
                &thing[1..]
            ),
        )
        .steps(n, at, |k| {
            let things = if k == 1 {
                thing.trim_end_matches('s')
            } else {
                thing
            };
            (format!("{k} {things}"), format!("{k} {things} kept."))
        })
    };
    vec![
        count(42, &[1, 10, 30, 50, 100], "nights", "nights", "100 Nights"),
        count(
            320,
            &[50, 100, 250, 500],
            "words",
            "words",
            "First 500 Words",
        ),
        Constellation::new(
            "ghibli",
            "The Ghibli Run",
            "Every Studio Ghibli film, start to end.",
        )
        .star("totoro", "My Neighbor Totoro", "Watched to the end.", true)
        .star("spirited", "Spirited Away", "Watched to the end.", true)
        .star(
            "mononoke",
            "Princess Mononoke",
            "Watched to the end.",
            false,
        )
        .star(
            "kiki",
            "Kiki's Delivery Service",
            "Watched to the end.",
            false,
        ),
        count(3, &[3, 7, 30], "days", "streak", "Unbroken"),
    ]
}

/// The gallery's one verb: any line, said back, so quick capture's line
/// has someone to answer it. And its sky.
fn commands() -> Commands {
    let mut commands = Commands::default();
    commands.add(
        "sky",
        |link, ()| async move { sky::show(&link, &sky()).await },
    );
    Desktop::new("Gallery")
        .verb(&[], |_, typed: Typed| async move {
            Ok::<_, String>(Some(Plan::said(
                format!("say “{}” back", typed.line),
                0.2,
                format!("Said “{}” back.", typed.line),
            )))
        })
        .register(&mut commands);
    commands
}

/// The gallery's moon: a world of its own carried in the gallery's window,
/// as Luna is in Terra's, to look at a moon's group, pages and colour.
const MOON: &str = r#"{
  "id": "moon",
  "name": "Moon",
  "tagline": "The gallery's moon, carried in its window",
  "role": "A moon at a glance",
  "repo": "Draysh/sol-quick",
  "parent": "gallery",
  "app": "gallery",
  "collections": [{ "id": "sky", "label": "Stars in your sky" }]
}"#;

fn moon() -> Moon {
    let mut commands = Commands::default();
    commands
        .add("hello", |link, ()| async move {
            Ok(format!(
                "Hello from {}, on a link of its own.",
                link.world()
            ))
        })
        .add("sky", |link, ()| async move {
            let nights =
                Constellation::new("nights", "100 Nights", "Nights kept, a star at each step.")
                    .steps(12, &[1, 10, 30, 100], |k| {
                        let n = if k == 1 { "night" } else { "nights" };
                        (format!("{k} {n}"), format!("{k} {n} kept."))
                    });
            sky::show(&link, &[nights]).await
        });
    Moon {
        manifest: MOON,
        version: env!("CARGO_PKG_VERSION"),
        icons: &[],
        handler: Arc::new(orbit::link::Ignore),
        commands,
        sample: None,
        prepare: None,
        source: "",
        module: "",
    }
}

fn main() {
    cxx_qt::init_crate!(sol_quick);
    cxx_qt::init_qml_module!("Sol.Design");

    // Always a preview: the Shell without pairing, on a throwaway copy
    // (`/tmp/sol-preview-gallery`), beside any world that is running.
    if std::env::var_os("SOL_PREVIEW").is_none() {
        // SAFETY: nothing else runs yet; the kit reads it from here on.
        unsafe { std::env::set_var("SOL_PREVIEW", "1") };
    }

    sol_quick::run_with(
        World {
            manifest: MANIFEST,
            update_key: "",
            version: env!("CARGO_PKG_VERSION"),
            bin: "sol-gallery",
            icons: &[(64, include_bytes!("../../assets/sol-tray.png"))],
            handler: Arc::new(orbit::link::Ignore),
            commands: commands(),
            main: concat!(
                "file://",
                env!("CARGO_MANIFEST_DIR"),
                "/examples/gallery/qml/Main.qml"
            ),
            source: env!("CARGO_MANIFEST_DIR"),
            sample: None,
            prepare: None,
            tray: &[],
            shortcuts: &[],
        },
        vec![moon()],
    )
}
