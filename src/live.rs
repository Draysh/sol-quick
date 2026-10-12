//! Screens without a build. A preview started with `SOL_QML_LIVE=1` reads
//! the kit's QML (`Sol.Design`) and the world's own (`Sol.<World>`) from
//! their checkouts instead of the copies compiled into the binary, so an
//! edited `.qml` shows the next time the preview starts, with no `cargo
//! build`. The folders are the ones the binary was built from (the kit's
//! and the world's `CARGO_MANIFEST_DIR`).
//!
//! Only files the compiled module already has are read this way: a new
//! `.qml` file is not in the module's type list until a build adds it
//! (one build, then edits to it need none). Assets and shaders are read
//! from the checkout too (QML reaches them relative to its file); a shader
//! still needs its `.qsb` rebuilt. Outside a preview the compiled QML is
//! always used.

use std::path::Path;

#[cxx_qt::bridge]
mod ffi {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qqmlapplicationengine.h");
        type QQmlApplicationEngine = cxx_qt_lib::QQmlApplicationEngine;

        include!("sol-quick/cpp/live.h");
        #[namespace = "sol"]
        #[cxx_name = "readFromDisk"]
        fn read_from_disk(engine: Pin<&mut QQmlApplicationEngine>, from: &str, to: &str);
    }
}

/// The kit's checkout, where `qml/` is.
const KIT: &str = env!("CARGO_MANIFEST_DIR");

/// Whether this run reads its screens from disk: a preview with `SOL_QML_LIVE=1`.
pub(crate) fn asked(preview: bool) -> bool {
    preview && std::env::var("SOL_QML_LIVE").is_ok_and(|v| v == "1")
}

/// Each module's folder in the resources and the checkout's folder that
/// stands in for it, for each checkout that is still there. `main` is the
/// world's main QML (`qrc:/qt/qml/Sol/Terra/qml/Main.qml`), `source` the
/// world's checkout.
pub(crate) fn folders(main: &str, source: &str, moons: &[(&str, &str)]) -> Vec<(String, String)> {
    let mut out = vec![(
        "qrc:/qt/qml/Sol/Design/qml/".to_owned(),
        format!("{KIT}/qml/"),
    )];
    if let Some(module) = main
        .strip_prefix("qrc:/qt/qml/")
        .and_then(|_| main.rsplit_once('/'))
        .map(|(folder, _)| format!("{folder}/"))
        && !source.is_empty()
    {
        out.push((module, format!("{source}/qml/")));
    }
    // Each carried moon's screens, from its own checkout.
    for (module, source) in moons.iter().filter(|(_, s)| !s.is_empty()) {
        out.push((
            format!("qrc:/qt/qml/{module}/qml/"),
            format!("{source}/qml/"),
        ));
    }
    out.retain(|(_, dir)| Path::new(dir).is_dir());
    out
}

/// Reads the QML under each of `folders` from its checkout from now on.
pub(crate) fn read_from_disk(
    mut engine: std::pin::Pin<&mut cxx_qt_lib::QQmlApplicationEngine>,
    folders: &[(String, String)],
) {
    for (from, to) in folders {
        tracing::info!("reading the screens under {from} from {to}");
        ffi::read_from_disk(engine.as_mut(), from, to);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_kit_and_the_world_are_read_from_their_checkouts() {
        let world = tempfile::tempdir().unwrap();
        std::fs::create_dir(world.path().join("qml")).unwrap();
        let source = world.path().to_str().unwrap();
        let found = folders("qrc:/qt/qml/Sol/Terra/qml/Main.qml", source, &[]);
        assert_eq!(
            found,
            [
                (
                    "qrc:/qt/qml/Sol/Design/qml/".to_owned(),
                    format!("{KIT}/qml/")
                ),
                (
                    "qrc:/qt/qml/Sol/Terra/qml/".to_owned(),
                    format!("{source}/qml/")
                ),
            ]
        );
        // A main read from disk already (the gallery), and a checkout that's gone.
        assert_eq!(folders("file:///x/Main.qml", source, &[]).len(), 1);
        assert_eq!(
            folders("qrc:/qt/qml/Sol/Terra/qml/Main.qml", "/nowhere", &[]).len(),
            1
        );
    }
}
