//! Builds the `Sol.Design` QML module: every `.qml` file in `qml/` (a file
//! that starts with `pragma Singleton` is registered as one), the assets
//! (fonts, the worlds' photographs, grain) and the compiled shaders, plus
//! the Rust QObjects in `src/bridge.rs`. `export()` hands the module to the
//! app that depends on this crate. The Qt version it was built against goes
//! into the binary as `SOL_QT_VERSION` (`--version` says it, and updates
//! for another Qt are refused).

use std::{fs, path::Path};

use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn files(dir: &str, keep: impl Fn(&Path) -> bool) -> Vec<String> {
    let mut out = Vec::new();
    let mut stack = vec![Path::new(dir).to_path_buf()];
    while let Some(dir) = stack.pop() {
        for entry in fs::read_dir(&dir).expect("a kit directory") {
            let path = entry.expect("a kit entry").path();
            if path.is_dir() {
                stack.push(path);
            } else if keep(&path) {
                out.push(path.to_string_lossy().into_owned());
            }
        }
    }
    out.sort();
    out
}

fn main() {
    // A file added to one of these folders reruns the build, as a changed one does.
    for dir in ["qml", "assets", "shaders", "cpp"] {
        println!("cargo::rerun-if-changed={dir}");
    }
    let mut module = QmlModule::new("Sol.Design");
    for file in files("qml", |p| p.extension().is_some_and(|e| e == "qml")) {
        println!("cargo::rerun-if-changed={file}");
        // `pragma Singleton` among the pragmas the file starts with.
        let singleton = fs::read_to_string(&file)
            .expect("a qml file")
            .lines()
            .map(str::trim)
            .take_while(|l| l.is_empty() || l.starts_with("pragma") || l.starts_with("//"))
            .any(|l| l == "pragma Singleton");
        module = module.qml_file(QmlFile::from(file.as_str()).singleton(singleton));
    }
    let resources = files("assets", |p| {
        !p.extension().is_some_and(|e| e == "txt" || e == "md")
    })
    .into_iter()
    .chain(files("shaders", |p| {
        p.extension().is_some_and(|e| e == "qsb")
    }))
    .collect::<Vec<_>>();
    for file in &resources {
        println!("cargo::rerun-if-changed={file}");
    }
    println!("cargo::rerun-if-env-changed=QMAKE");
    println!("cargo::rustc-env=SOL_QT_VERSION={}", qt_version());
    CxxQtBuilder::new_qml_module(module)
        .qt_module("Network")
        .qt_module("Quick")
        .qt_module("Multimedia")
        .files(["src/bridge.rs", "src/live.rs"])
        .qrc_resources(resources)
        .build()
        .export();
}

/// The Qt this build links: `qmake6 -query QT_VERSION` (or `$QMAKE`'s), the
/// same qmake cxx-qt-build finds.
fn qt_version() -> String {
    let qmakes = std::env::var("QMAKE")
        .ok()
        .into_iter()
        .chain(["qmake6".to_owned(), "qmake".to_owned()]);
    for qmake in qmakes {
        if let Ok(out) = std::process::Command::new(&qmake)
            .args(["-query", "QT_VERSION"])
            .output()
            && out.status.success()
        {
            let version = String::from_utf8_lossy(&out.stdout).trim().to_owned();
            if !version.is_empty() {
                return version;
            }
        }
    }
    "unknown".to_owned()
}
