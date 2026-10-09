//! Builds the `Sol.Design` QML module: every `.qml` file in `qml/` (a file
//! that starts with `pragma Singleton` is registered as one), the assets
//! (fonts, the worlds' photographs, grain) and the compiled shaders, plus
//! the Rust QObjects in `src/bridge.rs`. `export()` hands the module to the
//! app that depends on this crate.

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
    let mut module = QmlModule::new("Sol.Design");
    for file in files("qml", |p| p.extension().is_some_and(|e| e == "qml")) {
        println!("cargo::rerun-if-changed={file}");
        let singleton = fs::read_to_string(&file)
            .expect("a qml file")
            .lines()
            .next()
            .is_some_and(|l| l.trim_start().starts_with("pragma Singleton"));
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
    CxxQtBuilder::new_qml_module(module)
        .qt_module("Network")
        .qt_module("Quick")
        .qt_module("Multimedia")
        .files(["src/bridge.rs"])
        .qrc_resources(resources)
        .build()
        .export();
}
