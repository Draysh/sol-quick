//! Starting with the computer: an autostart entry for the installed copy,
//! which comes up in the tray without a window (`--login`). A moon its
//! planet starts has a flag of its own (`--background`), so a moon started
//! at login stays when its planet isn't running.

use std::path::PathBuf;

use orbit::install::{self, App};

use crate::commands::say;

/// The flag an app started at login runs with: no window, just the tray.
pub(crate) const LOGIN: &str = "--login";

/// Whether this process was started at login.
#[doc(hidden)]
pub fn at_login() -> bool {
    std::env::args().skip(1).any(|a| a == LOGIN)
}

fn entry_text(app: &App, bin: &std::path::Path) -> String {
    format!(
        "[Desktop Entry]\nType=Application\nName={}\nExec=\"{}\" {LOGIN}\nIcon={}\nTerminal=false\nX-GNOME-Autostart-enabled=true\n",
        app.name,
        bin.display(),
        app.bin_name(),
    )
}

/// Brings an entry written by a version before 1.0 (`--background`) to
/// today's flag; writes nothing when it is current, or there is none.
#[doc(hidden)]
pub fn refresh(app: &App) {
    let (Some(bin), Some(path)) = (installed_bin(app), autostart_entry(app)) else {
        return;
    };
    let Ok(text) = std::fs::read_to_string(&path) else {
        return;
    };
    if text.contains(" --background") && std::fs::write(&path, entry_text(app, &bin)).is_ok() {
        tracing::info!("the autostart entry now starts the app with {LOGIN}");
    }
}

/// Where the desktop starts the app at login: `~/.config/autostart/sol-<world>.desktop`.
fn autostart_entry(app: &App) -> Option<PathBuf> {
    Some(
        dirs::config_dir()?
            .join("autostart")
            .join(format!("{}.desktop", app.bin_name())),
    )
}

/// The installed binary, which is the one that can start with the computer.
fn installed_bin(app: &App) -> Option<PathBuf> {
    match install::here(app) {
        install::Here::Installed { path, .. } => Some(path),
        _ => None,
    }
}

/// For a planet that now carries `moon`: a moon that started with the
/// computer (its wind-down, its radio) hands that to the planet, which then
/// starts at login without a window and runs the moon's work. True when it
/// did.
/// `bin` is the planet's installed binary.
#[doc(hidden)]
pub fn hand_over(moon: &App, planet: &App, bin: &std::path::Path) -> bool {
    let (Some(entry), Some(ours)) = (
        autostart_entry(moon).filter(|e| e.exists()),
        autostart_entry(planet),
    ) else {
        return false;
    };
    if let Err(why) = std::fs::write(&ours, entry_text(planet, bin)) {
        tracing::warn!("couldn't start {} with the computer: {why}", planet.world);
        return false;
    }
    let _ = std::fs::remove_file(entry);
    true
}

/// Whether the app starts with the computer; None when this copy can't.
pub(crate) fn autostart(app: &App) -> Option<bool> {
    installed_bin(app)?;
    Some(autostart_entry(app)?.exists())
}

pub(crate) fn set_autostart(app: &App, on: bool) -> Result<(), String> {
    let bin = installed_bin(app).ok_or("only the installed copy starts with the computer")?;
    let path = autostart_entry(app).ok_or("no config folder for autostart")?;
    if on {
        std::fs::create_dir_all(path.parent().ok_or("no autostart folder")?).map_err(say)?;
        std::fs::write(&path, entry_text(app, &bin)).map_err(say)?;
    } else if path.exists() {
        std::fs::remove_file(&path).map_err(say)?;
    }
    Ok(())
}
