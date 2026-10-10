//! Starting with the computer: an autostart entry for the installed copy,
//! which comes up in the tray without a window (`--background`).

use std::path::PathBuf;

use orbit::install::{self, App};

use crate::commands::say;

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
        std::fs::write(
            &path,
            format!(
                "[Desktop Entry]\nType=Application\nName={}\nExec=\"{}\" --background\nIcon={}\nTerminal=false\nX-GNOME-Autostart-enabled=true\n",
                app.name,
                bin.display(),
                app.bin_name(),
            ),
        )
        .map_err(say)?;
    } else if path.exists() {
        std::fs::remove_file(&path).map_err(say)?;
    }
    Ok(())
}
