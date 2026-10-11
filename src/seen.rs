//! What pages last showed on this device (`Sol.callSeen`): a file per
//! key under the app's data folder, so a page has something to show on a
//! cold start while the fresh reply comes. Pruned after 30 days unseen.

use std::path::{Path, PathBuf};

use crate::app::runtime;

/// Where `remember` keeps what a page last showed: a file per key, named
/// by a stable hash of it (FNV-1a), under the app's data folder.
fn seen_file(key: &str) -> PathBuf {
    file_in(&runtime().data_dir, key)
}

fn file_in(data_dir: &Path, key: &str) -> PathBuf {
    let hash = key.bytes().fold(0xcbf2_9ce4_8422_2325_u64, |h, b| {
        (h ^ u64::from(b)).wrapping_mul(0x0100_0000_01b3)
    });
    data_dir.join("seen").join(format!("{hash:016x}.json"))
}

/// A command run as `Sol.callSeen` runs it, off the window's thread: what
/// the page showed last is read from disk and handed to `recalled` first,
/// then the command's reply (`ok`, its JSON) is kept for next time when it
/// is new. Answers the reply and whether it is what was recalled, so the
/// screens can leave what they show as it is without comparing the two.
pub(crate) async fn through(
    data_dir: PathBuf,
    key: String,
    reply: impl Future<Output = (bool, String)>,
    recalled: impl FnOnce(String),
) -> (bool, String, bool) {
    let path = file_in(&data_dir, &key);
    let kept = tokio::task::spawn_blocking(move || std::fs::read_to_string(path).ok())
        .await
        .ok()
        .flatten();
    if let Some(kept) = &kept {
        recalled(kept.clone());
    }
    let (ok, body) = reply.await;
    let same = ok && kept.as_deref() == Some(body.as_str());
    if ok {
        let json = body.clone();
        let path = file_in(&data_dir, &key);
        tokio::task::spawn_blocking(move || keep(&path, &json, same));
    }
    (ok, body, same)
}

/// Forgets what pages showed that nothing has shown for 30 days (a key per
/// day, like a diary's page, would otherwise keep every day).
pub(crate) fn prune() {
    let Ok(entries) = std::fs::read_dir(runtime().data_dir.join("seen")) else {
        return;
    };
    let month = std::time::Duration::from_secs(30 * 24 * 3600);
    for entry in entries.flatten() {
        let old = entry
            .metadata()
            .and_then(|m| m.modified())
            .is_ok_and(|t| t.elapsed().is_ok_and(|age| age > month));
        if old {
            let _ = std::fs::remove_file(entry.path());
        }
    }
}

/// What a page last showed, if it was kept.
pub(crate) fn recall(key: &str) -> Option<String> {
    std::fs::read_to_string(seen_file(key)).ok()
}

/// Keeps what a page shows; nothing is written when it is what was kept.
pub(crate) fn remember(key: &str, json: &str) {
    let path = seen_file(key);
    let same = std::fs::read_to_string(&path).is_ok_and(|kept| kept == json);
    keep(&path, json, same);
}

/// Writes what a page shows unless it is `same` as what the file holds,
/// in which case only its date moves on (once a day at most).
fn keep(path: &Path, json: &str, same: bool) {
    if same {
        // Still shown: kept from pruning (its date moved on once a day at most).
        let day = std::time::Duration::from_secs(24 * 3600);
        if let Ok(file) = std::fs::File::options().append(true).open(path)
            && file
                .metadata()
                .and_then(|m| m.modified())
                .is_ok_and(|t| t.elapsed().is_ok_and(|age| age > day))
        {
            let _ = file.set_modified(std::time::SystemTime::now());
        }
        return;
    }
    let part = path.with_extension("part");
    let wrote = path
        .parent()
        .map(std::fs::create_dir_all)
        .unwrap_or(Ok(()))
        .and_then(|()| std::fs::write(&part, json))
        .and_then(|()| std::fs::rename(&part, path));
    if let Err(e) = wrote {
        tracing::warn!("couldn't keep what {} showed: {e}", path.display());
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn what_a_page_showed_comes_first_and_is_kept_only_when_new() {
        let dir = tempfile::tempdir().unwrap();
        let run = |reply: &'static str| {
            let seen = std::sync::Arc::new(std::sync::Mutex::new(None));
            let got = seen.clone();
            let dir = dir.path().to_owned();
            async move {
                let out = through(
                    dir,
                    "home {}".into(),
                    async { (true, reply.to_owned()) },
                    move |s| {
                        *got.lock().unwrap() = Some(s);
                    },
                )
                .await;
                // The write happens beside the reply; give it its moment.
                tokio::time::sleep(std::time::Duration::from_millis(50)).await;
                (out, seen.lock().unwrap().take())
            }
        };
        // Nothing kept yet: nothing recalled, and the reply is new.
        let ((ok, body, same), recalled) = run(r#"{"n":1}"#).await;
        assert!(ok && !same);
        assert_eq!((body.as_str(), recalled), (r#"{"n":1}"#, None));
        let file = file_in(dir.path(), "home {}");
        assert_eq!(std::fs::read_to_string(&file).unwrap(), r#"{"n":1}"#);
        // The same again: recalled first, and said to be the same.
        let ((_, _, same), recalled) = run(r#"{"n":1}"#).await;
        assert!(same);
        assert_eq!(recalled.as_deref(), Some(r#"{"n":1}"#));
        // Something new is kept for next time.
        let ((_, _, same), _) = run(r#"{"n":2}"#).await;
        assert!(!same);
        assert_eq!(std::fs::read_to_string(&file).unwrap(), r#"{"n":2}"#);
        // A failure keeps nothing.
        let dir2 = dir.path().to_owned();
        let (ok, _, _) = through(
            dir2,
            "home {}".into(),
            async { (false, "no".to_owned()) },
            |_| {},
        )
        .await;
        assert!(!ok);
        tokio::time::sleep(std::time::Duration::from_millis(50)).await;
        assert_eq!(std::fs::read_to_string(&file).unwrap(), r#"{"n":2}"#);
    }
}
