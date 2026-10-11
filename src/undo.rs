//! Undo: the documents a write is about to change, read beforehand and
//! put back as they were from a notice's Undo.
//!
//! A world registers the write with what it touches
//! (`Commands::undoable`, or `creates` for one that makes documents);
//! `Sol.undoable(command, args, …)` runs it through the kit's `undoable`,
//! which keeps the documents as they were here, in memory, under a token,
//! and the notice's Undo sends the token back (`restore { undo }`). A
//! write with a way back of its own (a Navidrome star, Saturn's
//! `put_back`, which tells AniList too) takes the token with [`take`] and
//! does the rest itself.

use std::{
    collections::VecDeque,
    sync::{
        Mutex,
        atomic::{AtomicU64, Ordering},
    },
};

use orbit::link::Link;
use serde::{Deserialize, Serialize};
use serde_json::Value;

/// One document as it was before a write: `data` null when there was none.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Before {
    pub collection: String,
    pub id: String,
    #[serde(default)]
    pub data: Value,
}

/// Which document a write will change (`commands::doc` makes one).
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Which {
    pub collection: String,
    pub id: String,
}

/// How many writes can still be taken back: a notice offers Undo for
/// twelve seconds, so only the last few are ever asked for.
const KEPT: usize = 64;

static NEXT: AtomicU64 = AtomicU64::new(1);
static STASH: Mutex<VecDeque<(u64, Vec<Before>)>> = Mutex::new(VecDeque::new());

/// Keeps what a write is about to change; the token takes it back.
pub fn keep(before: Vec<Before>) -> u64 {
    let token = NEXT.fetch_add(1, Ordering::Relaxed);
    let mut stash = STASH.lock().unwrap_or_else(|e| e.into_inner());
    if stash.len() >= KEPT {
        stash.pop_front();
    }
    stash.push_back((token, before));
    token
}

/// What [`keep`] kept under `token`, once: None when it is gone (used, or
/// too long ago).
pub fn take(token: u64) -> Option<Vec<Before>> {
    let mut stash = STASH.lock().unwrap_or_else(|e| e.into_inner());
    let at = stash.iter().position(|(t, _)| *t == token)?;
    stash.remove(at).map(|(_, before)| before)
}

/// The documents as they are now, to put back later with [`restore`].
pub async fn snapshot(link: &Link, docs: &[Which]) -> anyhow::Result<Vec<Before>> {
    let mut out = Vec::with_capacity(docs.len());
    for d in docs {
        let data = link
            .get(&d.collection, &d.id)
            .await?
            .map(|doc| doc.data)
            .unwrap_or(Value::Null);
        out.push(Before {
            collection: d.collection.clone(),
            id: d.id.clone(),
            data,
        });
    }
    Ok(out)
}

/// Puts documents back as [`snapshot`] read them: rewritten, or deleted
/// where there was none. Only the world's own collections (`allowed`).
pub async fn restore(link: &Link, before: &[Before], allowed: &[String]) -> anyhow::Result<()> {
    for b in before {
        if !allowed.iter().any(|c| c == &b.collection) {
            anyhow::bail!("{} isn't one of this world's collections", b.collection);
        }
    }
    for b in before {
        let now = link.get(&b.collection, &b.id).await?;
        match (&b.data, now) {
            (Value::Null, Some(_)) => link.delete(&b.collection, &b.id).await?,
            (Value::Null, None) => {}
            (data, Some(doc)) if &doc.data == data => {}
            (data, _) => {
                link.put(&b.collection, &b.id, data.clone()).await?;
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use orbit::testing::offline;

    #[tokio::test]
    async fn a_write_is_undone_from_its_snapshot() {
        let (link, _dir) = offline("gallery").await;
        let allowed = vec!["checks".to_owned(), "habits".to_owned()];
        link.put("habits", "walk", serde_json::json!({ "name": "Walk" }))
            .await
            .unwrap();
        let which = [
            Which {
                collection: "habits".into(),
                id: "walk".into(),
            },
            Which {
                collection: "checks".into(),
                id: "walk_2026-10-11".into(),
            },
        ];
        let before = snapshot(&link, &which).await.unwrap();
        assert_eq!(before[1].data, Value::Null);
        // The write: a rename and a tick.
        link.put("habits", "walk", serde_json::json!({ "name": "Walk far" }))
            .await
            .unwrap();
        link.put(
            "checks",
            "walk_2026-10-11",
            serde_json::json!({ "done": true }),
        )
        .await
        .unwrap();
        restore(&link, &before, &allowed).await.unwrap();
        let walk = link.get("habits", "walk").await.unwrap().unwrap();
        assert_eq!(walk.data["name"], "Walk");
        assert!(
            link.get("checks", "walk_2026-10-11")
                .await
                .unwrap()
                .is_none()
        );
        // Only the world's own collections.
        let other = vec![Before {
            collection: "secrets".into(),
            id: "a".into(),
            data: Value::Null,
        }];
        assert!(restore(&link, &other, &allowed).await.is_err());
    }
}
