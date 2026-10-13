//! The Yozora look's pictures on this computer: each world's grounds (film
//! stills) and its navigator's portrait, in `~/.local/share/sol-yozora/` as
//! `<world>-ground-<n>.jpg` and `<world>-mascot.<jpg|png>`. Where they come
//! from is `yozora-art.json` beside this crate (TMDB's and AniList's image
//! CDNs, which need no key); every app fetches the ones that are missing in
//! the background as it starts (`fetch_missing`), and the window lists the
//! folder again once it has (`list`). `scripts/yozora-art.sh` reads the same
//! list. The pictures belong to their makers: they are only ever fetched to
//! this folder, never put in a repository, a fixture or a release.

use std::{
    collections::BTreeMap,
    path::{Path, PathBuf},
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
    time::Duration,
};

use serde::Deserialize;
use tokio::sync::Semaphore;

/// The list, as the kit ships it.
pub const LIST: &str = include_str!("../yozora-art.json");

/// The only hosts a picture is fetched from (a host or one under it).
const HOSTS: &[&str] = &["image.tmdb.org", "anilist.co"];
/// Downloads at once: a few, so a first start doesn't crowd the network.
const SLOTS: usize = 2;
/// The largest picture taken: a film's still at full size is a few megabytes.
const LARGEST: usize = 24 * 1024 * 1024;

/// Where every world's pictures come from.
#[derive(Clone, Debug, Deserialize)]
pub struct Art {
    /// Each world's grounds, in the order its sections take them.
    pub grounds: BTreeMap<String, Vec<Ground>>,
    /// Each world's navigator.
    pub mascots: BTreeMap<String, Mascot>,
}

/// One still: a file on TMDB's image CDN.
#[derive(Clone, Debug, Deserialize)]
pub struct Ground {
    /// The film's TMDB id (for choosing new stills with the script).
    pub film: u64,
    /// The still's file there, `/<name>.jpg`.
    pub path: String,
}

/// A navigator's portrait: a character's picture on AniList's CDN.
#[derive(Clone, Debug, Deserialize)]
pub struct Mascot {
    /// The film or series on AniList, and the character's name there (for finding a new portrait).
    pub media: u64,
    pub name: String,
    /// The portrait's address.
    pub url: String,
}

/// A picture to fetch: its file name in the folder (a mascot's without its
/// extension, which the picture decides) and its address.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Want {
    pub name: String,
    pub url: String,
}

impl Art {
    /// The list the kit ships.
    pub fn shipped() -> Self {
        serde_json::from_str(LIST).expect("yozora-art.json is the kit's own")
    }

    /// Every picture the look can stand on, by file name.
    pub fn wants(&self) -> Vec<Want> {
        let mut wants = Vec::new();
        for (world, grounds) in &self.grounds {
            for (n, g) in grounds.iter().enumerate() {
                wants.push(Want {
                    name: format!("{world}-ground-{}.jpg", n + 1),
                    url: format!("https://image.tmdb.org/t/p/original{}", g.path),
                });
            }
        }
        for (world, m) in &self.mascots {
            wants.push(Want {
                name: format!("{world}-mascot"),
                url: m.url.clone(),
            });
        }
        wants
    }
}

/// The folder the look's pictures live in, `~/.local/share/sol-yozora/`.
pub fn folder() -> Option<PathBuf> {
    dirs::data_dir().map(|d| d.join("sol-yozora"))
}

/// The pictures in `folder` (its `.jpg` and `.png` files), sorted: what the window stands on.
pub fn list(folder: &Path) -> Vec<String> {
    let mut files: Vec<String> = std::fs::read_dir(folder)
        .into_iter()
        .flatten()
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.extension().is_some_and(|x| x == "jpg" || x == "png"))
        .map(|p| p.to_string_lossy().into_owned())
        .collect();
    files.sort();
    files
}

/// Whether `want` is in `folder` already (a mascot as a `.jpg` or a `.png`).
fn has(folder: &Path, want: &Want) -> bool {
    let there = |name: &str| std::fs::metadata(folder.join(name)).is_ok_and(|m| m.len() > 0);
    if want.name.ends_with(".jpg") {
        there(&want.name)
    } else {
        there(&format!("{}.jpg", want.name)) || there(&format!("{}.png", want.name))
    }
}

/// The pictures of `art` that `folder` doesn't have yet.
pub fn missing(folder: &Path, art: &Art) -> Vec<Want> {
    art.wants()
        .into_iter()
        .filter(|w| !has(folder, w))
        .collect()
}

/// Whether `url` is one the look fetches from: https, on one of `HOSTS`.
pub fn allowed(url: &str) -> bool {
    let Some(rest) = url.strip_prefix("https://") else {
        return false;
    };
    let host = rest.split(['/', '?', '#']).next().unwrap_or_default();
    if host.contains(['@', ':']) {
        return false;
    }
    HOSTS.iter().any(|h| {
        host.strip_suffix(h)
            .is_some_and(|sub| sub.is_empty() || sub.ends_with('.'))
    })
}

/// The extension a picture's bytes call for, or None when they aren't a JPEG or a PNG.
fn kind(bytes: &[u8]) -> Option<&'static str> {
    match bytes {
        [0xFF, 0xD8, 0xFF, ..] => Some("jpg"),
        [0x89, b'P', b'N', b'G', ..] => Some("png"),
        _ => None,
    }
}

/// Names the half-written files, so two downloads never share one.
static PART: AtomicU64 = AtomicU64::new(0);

/// Fetches every picture of the shipped list that isn't in `folder` yet,
/// a few at a time, each written whole or not at all. Reads the folder and
/// writes nothing more when nothing is missing. Returns how many came.
pub async fn fetch_missing(folder: &Path) -> usize {
    let wants = missing(folder, &Art::shipped());
    if wants.is_empty() {
        return 0;
    }
    let http = match reqwest::Client::builder()
        .user_agent(concat!("Sol/", env!("CARGO_PKG_VERSION")))
        .connect_timeout(Duration::from_secs(20))
        .build()
    {
        Ok(http) => http,
        Err(e) => {
            tracing::warn!("no client for the look's pictures: {e}");
            return 0;
        }
    };
    fetch(&http, folder, wants, allowed).await
}

/// Fetches `wants` into `folder` from the addresses `allow` lets through.
pub async fn fetch(
    http: &reqwest::Client,
    folder: &Path,
    wants: Vec<Want>,
    allow: fn(&str) -> bool,
) -> usize {
    let wants: Vec<Want> = wants
        .into_iter()
        .filter(|w| {
            let ok = allow(&w.url);
            if !ok {
                tracing::warn!(url = %w.url, "a picture for the look from a host it doesn't fetch from");
            }
            ok
        })
        .collect();
    if wants.is_empty() || tokio::fs::create_dir_all(folder).await.is_err() {
        return 0;
    }
    let slots = Arc::new(Semaphore::new(SLOTS));
    let mut tasks = tokio::task::JoinSet::new();
    for want in wants {
        let (http, folder, slots) = (http.clone(), folder.to_owned(), slots.clone());
        tasks.spawn(async move {
            let _slot = slots.acquire_owned().await.ok()?;
            match one(&http, &folder, &want).await {
                Ok(file) => Some(file),
                Err(e) => {
                    tracing::warn!(name = %want.name, "the look's picture didn't come: {e:#}");
                    None
                }
            }
        });
    }
    let mut came = 0;
    while let Some(done) = tasks.join_next().await {
        if matches!(done, Ok(Some(_))) {
            came += 1;
        }
    }
    if came > 0 {
        tracing::info!(came, "the look's pictures fetched");
    }
    came
}

/// One picture into `folder`: fetched, checked to be a JPEG or a PNG, written
/// beside its place and moved there, so the folder never holds half a picture.
async fn one(http: &reqwest::Client, folder: &Path, want: &Want) -> anyhow::Result<PathBuf> {
    let res = http
        .get(&want.url)
        .timeout(Duration::from_secs(120))
        .send()
        .await?
        .error_for_status()?;
    if res.content_length().is_some_and(|n| n as usize > LARGEST) {
        anyhow::bail!("larger than a picture for the look should be");
    }
    let bytes = res.bytes().await?;
    if bytes.len() > LARGEST {
        anyhow::bail!("larger than a picture for the look should be");
    }
    let Some(ext) = kind(&bytes) else {
        anyhow::bail!("not a JPEG or a PNG");
    };
    let name = if want.name.ends_with(".jpg") {
        want.name.clone()
    } else {
        format!("{}.{ext}", want.name)
    };
    let file = folder.join(&name);
    let part = folder.join(format!(
        ".{name}.{}.part",
        PART.fetch_add(1, Ordering::Relaxed)
    ));
    if let Err(e) = async {
        tokio::fs::write(&part, &bytes).await?;
        tokio::fs::rename(&part, &file).await
    }
    .await
    {
        let _ = tokio::fs::remove_file(&part).await;
        return Err(e.into());
    }
    Ok(file)
}

#[cfg(test)]
mod tests {
    use super::*;
    use orbit::testing::{FakeHttp, Reply};

    const JPEG: &[u8] = &[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3];
    const PNG: &[u8] = &[0x89, b'P', b'N', b'G', 1, 2, 3];

    fn anywhere(_: &str) -> bool {
        true
    }

    #[test]
    fn the_shipped_list_names_every_picture_the_look_reads() {
        let wants = Art::shipped().wants();
        let names: Vec<&str> = wants.iter().map(|w| w.name.as_str()).collect();
        for world in ["saturn", "mercury", "neptune", "terra"] {
            for n in 1..=3 {
                assert!(names.contains(&format!("{world}-ground-{n}.jpg").as_str()));
            }
            assert!(names.contains(&format!("{world}-mascot").as_str()));
        }
        assert!(names.contains(&"luna-ground-1.jpg") && names.contains(&"luna-ground-2.jpg"));
        assert_eq!(wants.len(), 18);
        assert!(
            wants.iter().all(|w| allowed(&w.url)),
            "every address is on a host the look fetches from"
        );
        assert!(
            wants[0]
                .url
                .starts_with("https://image.tmdb.org/t/p/original/")
        );
    }

    #[test]
    fn only_the_picture_services_over_https() {
        assert!(allowed("https://image.tmdb.org/t/p/original/a.jpg"));
        assert!(allowed(
            "https://s4.anilist.co/file/anilistcdn/character/large/b1.png"
        ));
        assert!(!allowed("http://image.tmdb.org/t/p/original/a.jpg"));
        assert!(!allowed("https://evilanilist.co/a.png"));
        assert!(!allowed("https://anilist.co.example.com/a.png"));
        assert!(!allowed("https://image.tmdb.org@example.com/a.jpg"));
        assert!(!allowed("https://example.com/image.tmdb.org/a.jpg"));
    }

    #[test]
    fn what_is_there_already_is_not_missing() {
        let dir = tempfile::tempdir().unwrap();
        let art = Art::shipped();
        assert_eq!(missing(dir.path(), &art).len(), 18);
        std::fs::write(dir.path().join("saturn-ground-1.jpg"), JPEG).unwrap();
        // A portrait counts as there in either kind; an empty file doesn't count.
        std::fs::write(dir.path().join("saturn-mascot.jpg"), JPEG).unwrap();
        std::fs::write(dir.path().join("terra-mascot.png"), PNG).unwrap();
        std::fs::write(dir.path().join("mercury-ground-1.jpg"), b"").unwrap();
        let left: Vec<String> = missing(dir.path(), &art)
            .into_iter()
            .map(|w| w.name)
            .collect();
        assert_eq!(left.len(), 15);
        assert!(!left.contains(&"saturn-ground-1.jpg".into()));
        assert!(!left.contains(&"saturn-mascot".into()) && !left.contains(&"terra-mascot".into()));
        assert!(left.contains(&"mercury-ground-1.jpg".into()));
    }

    #[tokio::test]
    async fn fetches_what_is_missing_whole_and_by_its_kind() {
        let http = FakeHttp::routes([
            ("GET /still.jpg", Reply::ok(JPEG)),
            ("GET /face.png", Reply::ok(PNG)),
            ("GET /page.html", Reply::ok("<html>not a picture</html>")),
        ]);
        let dir = tempfile::tempdir().unwrap();
        let folder = dir.path().join("sol-yozora");
        let want = |name: &str, path: &str| Want {
            name: name.into(),
            url: format!("{}{path}", http.url()),
        };
        let wants = vec![
            want("saturn-ground-1.jpg", "/still.jpg"),
            want("saturn-mascot", "/face.png"),
            want("terra-ground-1.jpg", "/page.html"),
            want("terra-ground-2.jpg", "/gone.jpg"),
        ];
        let came = fetch(&reqwest::Client::new(), &folder, wants, anywhere).await;
        assert_eq!(came, 2);
        assert_eq!(
            std::fs::read(folder.join("saturn-ground-1.jpg")).unwrap(),
            JPEG
        );
        assert_eq!(
            std::fs::read(folder.join("saturn-mascot.png")).unwrap(),
            PNG
        );
        // What wasn't a picture, or didn't come, left nothing behind, not even half.
        let mut names: Vec<String> = std::fs::read_dir(&folder)
            .unwrap()
            .map(|e| e.unwrap().file_name().to_string_lossy().into_owned())
            .collect();
        names.sort();
        assert_eq!(names, ["saturn-ground-1.jpg", "saturn-mascot.png"]);
        let listed = list(&folder);
        assert_eq!(listed.len(), 2);
        assert!(listed[0].ends_with("/saturn-ground-1.jpg"));
    }

    #[tokio::test]
    async fn nothing_is_fetched_or_written_from_a_host_not_on_the_list() {
        let http = FakeHttp::routes([("GET /still.jpg", Reply::ok(JPEG))]);
        let dir = tempfile::tempdir().unwrap();
        let folder = dir.path().join("sol-yozora");
        let wants = vec![Want {
            name: "saturn-ground-1.jpg".into(),
            url: format!("{}/still.jpg", http.url()),
        }];
        assert_eq!(
            fetch(&reqwest::Client::new(), &folder, wants, allowed).await,
            0
        );
        assert!(http.requests().is_empty());
        assert!(
            !folder.exists(),
            "no folder made when there is nothing to fetch"
        );
    }

    #[tokio::test]
    async fn nothing_missing_writes_nothing() {
        let dir = tempfile::tempdir().unwrap();
        let folder = dir.path().join("sol-yozora");
        assert_eq!(
            fetch(&reqwest::Client::new(), &folder, Vec::new(), allowed).await,
            0
        );
        assert!(!folder.exists());
    }
}
