//! Moments (`Moment.qml`): a scene the window plays once for an occasion
//! (a series finished, every habit done today, a memory from a year ago).
//! Each occasion is played once for the person, not once per device: the
//! world keeps the ones shown in its own collection `moments` (one small
//! document each, listed in its manifest), so another device that syncs
//! it doesn't play the scene again. (Undo's snapshots are in `undo`.)

use orbit::link::Link;
use serde::{Deserialize, Serialize};

/// Where a world keeps the moments it has shown.
pub const MOMENTS: &str = "moments";

/// The document id for an occasion (`saturn.finished.anime:21`): letters,
/// digits, `-` and `_` only, at most 128 (the protocol's id rule), so any
/// occasion name works.
pub fn occasion_id(occasion: &str) -> String {
    let mut id: String = occasion
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '-' || c == '_' {
                c
            } else {
                '_'
            }
        })
        .collect();
    if id.len() > 128 {
        // Long ones keep their start and a fingerprint of the rest.
        let tail = format!("_{:016x}", fingerprint(occasion));
        id.truncate(128 - tail.len());
        id.push_str(&tail);
    }
    id
}

fn fingerprint(text: &str) -> u64 {
    // FNV-1a: stable across runs and versions, unlike the std hasher.
    text.bytes().fold(0xcbf2_9ce4_8422_2325, |h, b| {
        (h ^ u64::from(b)).wrapping_mul(0x0100_0000_01b3)
    })
}

/// What is kept for a moment shown.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Shown {
    pub occasion: String,
    /// When, RFC 3339.
    pub at: String,
    /// The device it was shown on.
    pub device: String,
}

/// Whether `occasion` is new to the person: true the first time (it is
/// recorded then), false ever after, on this device or another.
pub async fn first_time(link: &Link, occasion: &str, device: &str) -> anyhow::Result<bool> {
    let id = occasion_id(occasion);
    if link.get(MOMENTS, &id).await?.is_some() {
        return Ok(false);
    }
    let shown = Shown {
        occasion: occasion.to_owned(),
        at: chrono::Utc::now().to_rfc3339(),
        device: device.to_owned(),
    };
    link.put_as(MOMENTS, &id, &shown).await?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;
    use orbit::testing::offline;

    #[test]
    fn any_occasion_makes_a_valid_id() {
        assert_eq!(
            occasion_id("saturn.finished.anime:21"),
            "saturn_finished_anime_21"
        );
        let long = "x".repeat(300);
        let id = occasion_id(&long);
        assert_eq!(id.len(), 128);
        assert_ne!(id, occasion_id(&"x".repeat(301)), "long ones stay apart");
    }

    #[tokio::test]
    async fn a_moment_plays_once_per_occasion() {
        let (link, _dir) = offline("gallery").await;
        assert!(
            first_time(&link, "terra.all-done.2026-10-11", "Desk")
                .await
                .unwrap()
        );
        assert!(
            !first_time(&link, "terra.all-done.2026-10-11", "Desk")
                .await
                .unwrap()
        );
        // Another device sees what this one recorded: the same document.
        assert!(
            !first_time(&link, "terra.all-done.2026-10-11", "Laptop")
                .await
                .unwrap()
        );
        // Another day is another occasion.
        assert!(
            first_time(&link, "terra.all-done.2026-10-12", "Desk")
                .await
                .unwrap()
        );
        let kept: Shown = link
            .get_as(MOMENTS, "terra_all-done_2026-10-11")
            .await
            .unwrap()
            .unwrap();
        assert_eq!(kept.device, "Desk");
    }
}
