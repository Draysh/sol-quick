//! The kit's type: the fonts in `assets/fonts/` (packed into the module)
//! are made known to the app once, before its first window, with the face
//! that draws what each lacks (Japanese in the sans: Zen Kaku Gothic New).
//! A world's app adds the faces it carries itself (its title face) with
//! `add_font` before it runs. `cpp/fonts.h` does it; `Theme` names the
//! families.

use std::sync::Mutex;

#[cxx_qt::bridge]
mod ffi {
    unsafe extern "C++" {
        include!("sol-quick/cpp/fonts.h");
        #[namespace = "sol"]
        #[cxx_name = "loadFonts"]
        fn load_fonts();
        #[namespace = "sol"]
        #[cxx_name = "addFont"]
        fn add_font(data: &[u8]);
    }
}

/// The faces the app carries itself, waiting for the window.
static ADDED: Mutex<Vec<&'static [u8]>> = Mutex::new(Vec::new());

/// Makes a font the app carries itself known to it, beside the kit's: a
/// world's own title face, from a file in its repository. Call it before
/// `run`, once for each file:
///
/// ```ignore
/// sol_quick::add_font(include_bytes!("../assets/fonts/Keifont.ttf"));
/// ```
pub fn add_font(data: &'static [u8]) {
    ADDED.lock().unwrap_or_else(|e| e.into_inner()).push(data);
}

/// Registers the kit's fonts and the app's own. Call it once the QGuiApplication exists.
pub(crate) fn load() {
    ffi::load_fonts();
    for data in ADDED.lock().unwrap_or_else(|e| e.into_inner()).iter() {
        ffi::add_font(data);
    }
}
