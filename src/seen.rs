//! What pages last showed on this device (`Sol.callSeen`): a file per
//! key under the app's data folder, so a page has something to show on a
//! cold start while the fresh reply comes. Pruned after 30 days unseen.

use std::path::PathBuf;

use crate::app::runtime;

/// Where `remember` keeps what a page last showed: a file per key, named
/// by a stable hash of it (FNV-1a), under the app's data folder.
fn seen_file(key: &str) -> PathBuf {
    let hash = key.bytes().fold(0xcbf2_9ce4_8422_2325_u64, |h, b| {
        (h ^ u64::from(b)).wrapping_mul(0x0100_0000_01b3)
    });
    runtime()
        .data_dir
        .join("seen")
        .join(format!("{hash:016x}.json"))
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
    if std::fs::read_to_string(&path).is_ok_and(|kept| kept == json) {
        // Still shown: kept from pruning (its date moved on once a day at most).
        let day = std::time::Duration::from_secs(24 * 3600);
        if let Ok(file) = std::fs::File::options().append(true).open(&path)
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
        .and_then(|()| std::fs::rename(&part, &path));
    if let Err(e) = wrote {
        tracing::warn!("couldn't keep what {} showed: {e}", path.display());
    }
}
