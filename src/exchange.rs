//! Export and import: everything a world keeps in its own collections, as
//! one JSON file the person can keep, read, and bring back on any device.
//!
//! ```json
//! { "world": "terra", "version": 1, "exported_at": "2026-10-10T20:14:00Z",
//!   "collections": { "habits": [{ "id": "walk", "data": { … } }] } }
//! ```
//!
//! An import goes through the Link like any other write (so it reaches
//! Sol and the other devices), merges by id and never deletes: a document
//! the file doesn't have stays, one it has that isn't here is added, and
//! one that differs is replaced. Collections the world doesn't keep are
//! left out. The shared commands `export_world` and `import_world` (and the
//! kit's `ExportCard`) are built on this.

use std::{
    collections::BTreeMap,
    path::{Path, PathBuf},
};

use anyhow::{Context, bail};
use orbit::{link::Link, world::Collection};
use serde::{Deserialize, Serialize};
use serde_json::Value;

/// The shape of the file, written as `version`.
pub const VERSION: u32 = 1;

/// An export file.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Exported {
    pub world: String,
    pub version: u32,
    /// When it was made, in RFC 3339 (UTC).
    pub exported_at: String,
    /// Every document of each collection, by collection id.
    pub collections: BTreeMap<String, Vec<Row>>,
}

/// One document: its id and what it holds.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Row {
    pub id: String,
    pub data: Value,
}

/// What an import adds and replaces in one collection.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize)]
pub struct Counts {
    pub collection: String,
    /// The collection's name as the manifest says it (`Diary days`).
    pub label: String,
    /// Documents that aren't here yet.
    pub added: usize,
    /// Documents here that the file has differently.
    pub replaced: usize,
    /// Documents the file has just as they are here.
    pub same: usize,
}

/// What an import would do (or did): per collection and in all, with the
/// collections in the file this world doesn't keep.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize)]
pub struct Plan {
    pub world: String,
    pub exported_at: String,
    pub collections: Vec<Counts>,
    pub added: usize,
    pub replaced: usize,
    pub same: usize,
    /// Collections in the file that this world doesn't keep, left out.
    pub skipped: Vec<String>,
}

/// Every live document in `collections`, as an export.
pub async fn export(link: &Link, collections: &[Collection]) -> anyhow::Result<Exported> {
    let mut out = BTreeMap::new();
    for collection in collections {
        let rows = link
            .list(&collection.id)
            .await?
            .into_iter()
            .map(|doc| Row {
                id: doc.id,
                data: doc.data,
            })
            .collect();
        out.insert(collection.id.clone(), rows);
    }
    Ok(Exported {
        world: link.world().to_owned(),
        version: VERSION,
        exported_at: chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true),
        collections: out,
    })
}

/// Writes the export into `dir` as `sol-<world>-<stamp>.json`; its path.
pub async fn write(
    link: &Link,
    collections: &[Collection],
    dir: &Path,
    stamp: &str,
) -> anyhow::Result<(PathBuf, usize)> {
    let exported = export(link, collections).await?;
    let count = exported.collections.values().map(Vec::len).sum();
    std::fs::create_dir_all(dir)?;
    let path = dir.join(format!("sol-{}-{stamp}.json", exported.world));
    std::fs::write(&path, serde_json::to_vec_pretty(&exported)?)
        .with_context(|| format!("couldn't write {}", path.display()))?;
    Ok((path, count))
}

/// Reads an export file, refusing one from another world or a newer shape.
pub fn read(path: &Path, world: &str) -> anyhow::Result<Exported> {
    let bytes = std::fs::read(path).with_context(|| format!("couldn't read {}", path.display()))?;
    let file: Exported = serde_json::from_slice(&bytes).context("this isn't a Sol export file")?;
    if file.world != world {
        bail!("this file is {}’s export, not {world}’s", file.world);
    }
    if file.version > VERSION {
        bail!("this file was made by a newer version of the app; update it first");
    }
    Ok(file)
}

/// What importing `file` would add and replace here, without writing.
pub async fn plan(
    link: &Link,
    collections: &[Collection],
    file: &Exported,
) -> anyhow::Result<Plan> {
    run(link, collections, file, false).await
}

/// Imports `file`: adds and replaces through the Link, deletes nothing.
pub async fn import(
    link: &Link,
    collections: &[Collection],
    file: &Exported,
) -> anyhow::Result<Plan> {
    run(link, collections, file, true).await
}

async fn run(
    link: &Link,
    collections: &[Collection],
    file: &Exported,
    write: bool,
) -> anyhow::Result<Plan> {
    let mut plan = Plan {
        world: file.world.clone(),
        exported_at: file.exported_at.clone(),
        skipped: file
            .collections
            .keys()
            .filter(|name| !collections.iter().any(|c| &c.id == *name))
            .cloned()
            .collect(),
        ..Plan::default()
    };
    for collection in collections {
        let Some(rows) = file.collections.get(&collection.id) else {
            continue;
        };
        let mut counts = Counts {
            collection: collection.id.clone(),
            label: collection.label.clone(),
            ..Counts::default()
        };
        for row in rows {
            if row.id.is_empty() || row.data.is_null() {
                continue;
            }
            match link.get(&collection.id, &row.id).await? {
                Some(doc) if doc.data == row.data => {
                    counts.same += 1;
                    continue;
                }
                Some(_) => counts.replaced += 1,
                None => counts.added += 1,
            }
            if write {
                link.put(&collection.id, &row.id, row.data.clone()).await?;
            }
        }
        plan.added += counts.added;
        plan.replaced += counts.replaced;
        plan.same += counts.same;
        plan.collections.push(counts);
    }
    Ok(plan)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    async fn offline(dir: &Path) -> Link {
        Link::open(orbit::link::Config {
            world: "terra".into(),
            dir: dir.to_owned(),
            device: "Test".into(),
            platform: None,
            version: "0.1.0".into(),
            tokens: orbit::link::Tokens::File,
        })
        .await
        .unwrap()
    }

    fn kept() -> Vec<Collection> {
        ["habits", "entries"]
            .map(|id| Collection {
                id: id.into(),
                label: id.into(),
            })
            .to_vec()
    }

    #[tokio::test]
    async fn an_export_comes_back_whole_and_merges_by_id() {
        let (a, b) = (tempfile::tempdir().unwrap(), tempfile::tempdir().unwrap());
        let here = offline(a.path()).await;
        here.put("habits", "walk", json!({ "name": "Walk", "rating": 7.3 }))
            .await
            .unwrap();
        here.put("entries", "2026-10-10", json!({ "mood": 4 }))
            .await
            .unwrap();
        here.put("stray", "x", json!({})).await.unwrap();

        let (path, count) = write(&here, &kept(), a.path(), "now").await.unwrap();
        assert_eq!(count, 2);
        assert!(path.ends_with("sol-terra-now.json"));
        let file = read(&path, "terra").unwrap();
        assert_eq!(file.version, VERSION);
        assert_eq!(file.collections["habits"][0].id, "walk");
        assert!(!file.collections.contains_key("stray"));

        // Another device: one document differs, one is its own, one is missing.
        let there = offline(b.path()).await;
        there
            .put("habits", "walk", json!({ "name": "Walk outside" }))
            .await
            .unwrap();
        there
            .put("habits", "read", json!({ "name": "Read" }))
            .await
            .unwrap();
        let ahead = plan(&there, &kept(), &file).await.unwrap();
        assert_eq!((ahead.added, ahead.replaced, ahead.same), (1, 1, 0));
        // A plan writes nothing.
        assert!(there.get("entries", "2026-10-10").await.unwrap().is_none());

        let done = import(&there, &kept(), &file).await.unwrap();
        assert_eq!(done, ahead);
        let walk = there.get("habits", "walk").await.unwrap().unwrap();
        assert_eq!(walk.data, json!({ "name": "Walk", "rating": 7.3 }));
        // Nothing is deleted: the document the file didn't have stays.
        assert!(there.get("habits", "read").await.unwrap().is_some());
        // Importing again changes nothing.
        let again = plan(&there, &kept(), &file).await.unwrap();
        assert_eq!((again.added, again.replaced, again.same), (0, 0, 2));
    }

    #[tokio::test]
    async fn another_worlds_file_and_strange_collections_stay_out() {
        let dir = tempfile::tempdir().unwrap();
        let link = offline(dir.path()).await;
        let path = dir.path().join("luna.json");
        let file = json!({ "world": "luna", "version": 1, "exported_at": "", "collections": {} });
        std::fs::write(&path, file.to_string()).unwrap();
        assert!(read(&path, "terra").is_err());
        std::fs::write(&path, "not json").unwrap();
        assert!(read(&path, "terra").is_err());

        let file: Exported = serde_json::from_value(json!({
            "world": "terra", "version": 1, "exported_at": "",
            "collections": { "ghosts": [{ "id": "a", "data": {} }], "habits": [{ "id": "", "data": {} }] }
        }))
        .unwrap();
        let done = import(&link, &kept(), &file).await.unwrap();
        assert_eq!(done.skipped, vec!["ghosts".to_string()]);
        assert_eq!(done.added, 0);
        assert!(link.list("ghosts").await.unwrap().is_empty());
    }
}
