//! The kit's type: the fonts in `assets/fonts/` (packed into the module)
//! are made known to the app once, before its first window, with the face
//! that draws what each lacks (Japanese in the sans: Zen Kaku Gothic New).
//! `cpp/fonts.h` does it; `Theme` names the families.

#[cxx_qt::bridge]
mod ffi {
    unsafe extern "C++" {
        include!("sol-quick/cpp/fonts.h");
        #[namespace = "sol"]
        #[cxx_name = "loadFonts"]
        fn load_fonts();
    }
}

/// Registers the kit's fonts. Call it once the QGuiApplication exists.
pub(crate) fn load() {
    ffi::load_fonts();
}
