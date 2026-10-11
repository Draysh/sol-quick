//! What a running world tells the desktop around it: a small JSON status
//! (what's playing, habits left, cards due) in
//! `$XDG_RUNTIME_DIR/sol/<world>.json`, for the bar, the launcher and the
//! terminal to read. The runtime folder is in memory, so this never touches
//! the disk; the file is written only when the status changes, and goes
//! when the app does.
//!
//! A world says what its status is with a command named `status` (no
//! arguments, a JSON object back; `null` says nothing for now), which
//! `desktop::Desktop::status` registers. The kit
//! asks it when the app starts, when the world's documents or settings
//! change, once a minute (so "today" turns over), and whenever the world
//! calls [`refresh`] (Neptune, when the track changes).
//!
//! The file holds that object with `world`, `name`, `pid` (gone from
//! `/proc` means the app crashed and the file is stale) and `at` (when it
//! last changed, in Unix seconds) beside it. A preview writes
//! `preview-<world>.json` instead, so it never stands in for the real app.
//!
//! What the desktop and the other worlds ask a running app through its
//! door (`--do`, `--find`, a question) is in `door`.

use std::{path::PathBuf, sync::OnceLock, time::Duration};

use orbit::link::Update;
use serde_json::Value;
use tokio::sync::Notify;

use crate::app::Runtime;

static WAKE: Notify = Notify::const_new();
static WRITTEN: OnceLock<PathBuf> = OnceLock::new();

/// Asks for the status again now: for news the world's documents don't
/// carry (the track changed, playback paused).
pub fn refresh() {
    WAKE.notify_one();
}

/// Where `world`'s status lives: `$XDG_RUNTIME_DIR/sol/<world>.json`
/// (`preview-<world>.json` for a preview). None without a runtime folder:
/// then there is no status, rather than one on the disk.
pub fn file(world: &str, preview: bool) -> Option<PathBuf> {
    let dir = dirs::runtime_dir()?.join("sol");
    Some(dir.join(if preview {
        format!("preview-{world}.json")
    } else {
        format!("{world}.json")
    }))
}

/// The file's text: the world's own object with who wrote it and when.
fn compose(world: &str, name: &str, own: &str, at: i64) -> String {
    let mut out = serde_json::Map::new();
    if let Ok(Value::Object(fields)) = serde_json::from_str::<Value>(own) {
        out.extend(fields);
    }
    out.insert("world".into(), world.into());
    out.insert("name".into(), name.into());
    out.insert("pid".into(), std::process::id().into());
    out.insert("at".into(), at.into());
    let mut text = serde_json::to_string(&Value::Object(out)).unwrap_or_default();
    text.push('\n');
    text
}

/// Writes the file whole (a reader never sees half of it), in a folder
/// only this person can read.
fn write(path: &std::path::Path, text: &str) -> std::io::Result<()> {
    let dir = path.parent().unwrap_or(path);
    std::fs::create_dir_all(dir)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(dir, std::fs::Permissions::from_mode(0o700));
    }
    let name = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("status");
    let tmp = dir.join(format!(".{name}.{}", std::process::id()));
    std::fs::write(&tmp, text)?;
    std::fs::rename(&tmp, path)
}

/// Waits for a reason to ask again: a refresh, a change in the world's
/// documents or settings (or the connection), or a minute gone by.
async fn reason(updates: &mut tokio::sync::broadcast::Receiver<Update>) {
    let minute = tokio::time::sleep(Duration::from_secs(60));
    tokio::pin!(minute);
    loop {
        tokio::select! {
            () = WAKE.notified() => return,
            () = &mut minute => return,
            update = updates.recv() => match update {
                Ok(Update::Changed(_) | Update::Settings | Update::Status(_))
                | Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => return,
                Ok(_) => {}
                // No more news from the link: the minute still turns.
                Err(tokio::sync::broadcast::error::RecvError::Closed) => {
                    (&mut minute).await;
                    return;
                }
            },
        }
    }
}

/// Keeps the status file current while the app runs, for a world that has
/// a `status` command.
#[doc(hidden)]
pub fn start(rt: &'static Runtime) {
    if !rt.commands.has("status") {
        return;
    }
    let Some(path) = file(rt.app.world, rt.preview) else {
        tracing::debug!("no runtime folder: no status for the desktop");
        return;
    };
    let _ = WRITTEN.set(path.clone());
    rt.tokio.spawn(async move {
        let mut updates = rt.link.subscribe();
        let mut last: Option<String> = None;
        loop {
            match rt
                .commands
                .call(rt.link.clone(), "status", Value::Null)
                .await
            {
                Ok(own) if last.as_deref() != Some(own.as_str()) => {
                    let text =
                        compose(rt.app.world, &rt.name, &own, chrono::Utc::now().timestamp());
                    match write(&path, &text) {
                        Ok(()) => last = Some(own),
                        Err(e) => tracing::debug!("couldn't write the status: {e}"),
                    }
                }
                Ok(_) => {}
                Err(why) => tracing::debug!("no status: {why}"),
            }
            reason(&mut updates).await;
            // A burst of changes (a sync) is asked about once.
            tokio::time::sleep(Duration::from_millis(300)).await;
        }
    });
}

/// Takes the status away as the app leaves.
#[doc(hidden)]
pub fn leave() {
    if let Some(path) = WRITTEN.get() {
        let _ = std::fs::remove_file(path);
    }
}

/// `--status`: prints the status of the copy running here, if one is.
#[doc(hidden)]
pub fn print(world: &str, name: &str, preview: bool) -> i32 {
    match file(world, preview).and_then(|p| std::fs::read_to_string(p).ok()) {
        Some(text) => {
            print!("{text}");
            0
        }
        None => {
            eprintln!("{name} isn't running.");
            1
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_file_says_who_wrote_it() {
        let text = compose(
            "neptune",
            "Neptune",
            r#"{"state":"playing","title":"Song"}"#,
            7,
        );
        let v: Value = serde_json::from_str(&text).unwrap();
        assert_eq!(v["world"], "neptune");
        assert_eq!(v["name"], "Neptune");
        assert_eq!(v["state"], "playing");
        assert_eq!(v["at"], 7);
        assert_eq!(v["pid"], std::process::id());
        // Nothing to say is still a status: the app runs.
        let v: Value = serde_json::from_str(&compose("terra", "Terra", "null", 1)).unwrap();
        assert_eq!(v["world"], "terra");
    }

    #[test]
    fn writes_whole_files() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("sol").join("terra.json");
        write(&path, "{\"a\":1}\n").unwrap();
        write(&path, "{\"a\":2}\n").unwrap();
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "{\"a\":2}\n");
        let left: Vec<_> = std::fs::read_dir(path.parent().unwrap()).unwrap().collect();
        assert_eq!(left.len(), 1, "no half-written files are left");
    }
}
