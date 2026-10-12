//! A collection read once and kept until it changes: `kept::<Card>(&link,
//! "cards")` reads every card the first time, and the same list again for
//! every command after, until a write here or a change from Sol touches that
//! collection (the link tells of both before the write returns), when the
//! next call reads it again. For a world whose commands each read the same
//! big collection (Mercury's cards, Saturn's titles, Terra's checks); the
//! list is shared (`Arc`), never copied.

use std::{
    any::{Any, TypeId},
    collections::HashMap,
    sync::{Arc, LazyLock, Mutex},
};

use orbit::link::{Link, Update};
use serde::de::DeserializeOwned;
use tokio::sync::broadcast::{Receiver, error::TryRecvError};

/// One collection's rows as `T`, each with its id, in id order.
pub type Rows<T> = Arc<Vec<(String, T)>>;

struct Slot<T> {
    news: Receiver<Update>,
    rows: Option<Rows<T>>,
}

/// The link (by its identity, so two links of one world never share), the
/// collection, the type.
type Key = (usize, &'static str, TypeId);

static SLOTS: LazyLock<Mutex<HashMap<Key, Arc<dyn Any + Send + Sync>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// `collection`'s live documents as `T` with their ids (documents of another
/// shape left out, as `Link::list_with_ids`), read again only after it
/// changed.
pub async fn kept<T>(link: &Link, collection: &'static str) -> anyhow::Result<Rows<T>>
where
    T: DeserializeOwned + Send + Sync + 'static,
{
    let key = (link.identity(), collection, TypeId::of::<T>());
    let slot: Arc<tokio::sync::Mutex<Slot<T>>> = {
        let mut slots = SLOTS
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        let any = slots
            .entry(key)
            .or_insert_with(|| {
                Arc::new(tokio::sync::Mutex::new(Slot::<T> {
                    news: link.subscribe(),
                    rows: None,
                }))
            })
            .clone();
        any.downcast::<tokio::sync::Mutex<Slot<T>>>()
            .expect("one type per key")
    };
    let mut slot = slot.lock().await;
    loop {
        match slot.news.try_recv() {
            Ok(Update::Changed(collections)) => {
                if collections.is_empty() || collections.iter().any(|c| c == collection) {
                    slot.rows = None;
                }
            }
            Ok(_) => {}
            Err(TryRecvError::Lagged(_)) => slot.rows = None,
            // The link this was kept for has gone and a new one took its place.
            Err(TryRecvError::Closed) => {
                slot.news = link.subscribe();
                slot.rows = None;
                break;
            }
            Err(TryRecvError::Empty) => break,
        }
    }
    if let Some(rows) = &slot.rows {
        return Ok(rows.clone());
    }
    let rows: Rows<T> = Arc::new(link.list_with_ids(collection).await?);
    slot.rows = Some(rows.clone());
    Ok(rows)
}

#[cfg(test)]
mod tests {
    use super::*;
    use orbit::testing::offline;
    use serde::Deserialize;
    use serde_json::json;

    #[derive(Deserialize, Debug, PartialEq)]
    struct Card {
        front: String,
    }

    #[tokio::test]
    async fn read_once_until_it_changes() {
        let (link, _dir) = offline("kept").await;
        link.put("cards", "a", json!({ "front": "猫" }))
            .await
            .unwrap();
        let first = kept::<Card>(&link, "cards").await.unwrap();
        let again = kept::<Card>(&link, "cards").await.unwrap();
        assert!(Arc::ptr_eq(&first, &again), "the same list, not read again");

        // Another collection changing keeps it.
        link.put("decks", "d", json!({ "name": "N5" }))
            .await
            .unwrap();
        assert!(Arc::ptr_eq(
            &first,
            &kept::<Card>(&link, "cards").await.unwrap()
        ));

        // Its own changing reads it again.
        link.put("cards", "b", json!({ "front": "犬" }))
            .await
            .unwrap();
        let after = kept::<Card>(&link, "cards").await.unwrap();
        assert!(!Arc::ptr_eq(&first, &after));
        assert_eq!(after.len(), 2);
        assert_eq!(
            after[1].1,
            Card {
                front: "犬".into()
            }
        );
    }

    #[tokio::test]
    async fn two_links_of_one_world_keep_their_own() {
        let (a, _da) = offline("kept-two").await;
        let (b, _db) = offline("kept-two").await;
        a.put("cards", "a", json!({ "front": "猫" })).await.unwrap();
        assert_eq!(kept::<Card>(&a, "cards").await.unwrap().len(), 1);
        assert!(kept::<Card>(&b, "cards").await.unwrap().is_empty());
    }
}
