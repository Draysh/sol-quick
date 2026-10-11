//! The questions the worlds' apps ask each other on this computer, with
//! their types, so the asker and the answerer read them alike. Each names
//! the world that answers it and its id; [`ask`] and [`tell`] put one
//! through that world's door (never starting it), and the answering world
//! takes it with `Desktop::asked` or `Desktop::told`.
//!
//! | Question | Answered by | Asked by | Answer |
//! | --- | --- | --- | --- |
//! | [`Furigana`] `ask furigana { lines }` | Mercury | Neptune | [`Readings`] |
//! | [`Say`] `ask say { text }` | Mercury | Triton | [`Spoken`] |
//! | [`Level`] `ask level` | Mercury | Triton | [`Known`] |
//! | [`AddWord`] `do add-word <word or JSON>` | Mercury | Neptune | a sentence |
//! | [`Now`] `ask now` | Neptune | Triton | [`Playing`] |
//! | [`Duck`] `do duck {"level","ms"}` | Neptune | Triton | a sentence |
//! | [`Pause`] `do pause` | Neptune | Luna | a sentence |
//!
//! The wire is what it was before these types (installed apps of other
//! versions ask and answer each other): each answering world keeps a
//! fixture of it (`fixtures/questions/<id>.json`, checked with
//! `testing::assert_asked` / `assert_told`), and each asker a copy.

use serde::{Deserialize, Serialize, de::DeserializeOwned};
use serde_json::Value;

use crate::door::{self, Unanswered};

/// A question with an answer (another world's `ask` command).
pub trait Ask: Serialize + DeserializeOwned + Send + 'static {
    /// The world that answers it.
    const WORLD: &'static str;
    /// The question's id.
    const ID: &'static str;
    type Answer: Serialize + DeserializeOwned + Send + 'static;
}

/// Something another world is told to do (its `do` command), answered
/// with one sentence. Its argument travels as text.
pub trait Tell: Sized + Send + 'static {
    /// The world that does it.
    const WORLD: &'static str;
    /// The action's id.
    const ID: &'static str;
    /// The argument as it travels.
    fn arg(&self) -> Option<String>;
    /// The argument as it arrived.
    fn read(arg: Option<&str>) -> Result<Self, String>;
}

/// Asks `Q::WORLD` through its door, off the async runtime, and reads the
/// answer. `Unanswered::NotRunning` says to do without.
pub async fn ask<Q: Ask>(question: Q) -> Result<Q::Answer, Unanswered> {
    let arg = serde_json::to_value(&question).unwrap_or(Value::Null);
    let answer = tokio::task::spawn_blocking(move || door::ask(Q::WORLD, Q::ID, arg))
        .await
        .unwrap_or(Err(Unanswered::NotRunning))?;
    serde_json::from_value(answer).map_err(|_| Unanswered::Old)
}

/// Tells `T::WORLD` to do it, off the async runtime: what it did.
pub async fn tell<T: Tell>(told: T) -> Result<String, Unanswered> {
    let arg = told.arg();
    tokio::task::spawn_blocking(move || door::tell(T::WORLD, T::ID, arg))
        .await
        .unwrap_or(Err(Unanswered::NotRunning))
}

/// Readings over Japanese lines, from Mercury's dictionary (Neptune's
/// lyrics). At most a few hundred lines of a few hundred characters each
/// are read.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Furigana {
    #[serde(default)]
    pub lines: Vec<String>,
}

/// Each line as its words, in the lines' order.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Readings {
    pub lines: Vec<Vec<Word>>,
}

/// One word of a line: its parts with readings over the kanji, and the
/// dictionary form and entry for a word Mercury knows.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Word {
    pub parts: Vec<Part>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub word: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub entry: Option<i64>,
}

/// Text, and its reading when it has kanji.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Part {
    pub base: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rt: Option<String>,
}

impl Ask for Furigana {
    const WORLD: &'static str = "mercury";
    const ID: &'static str = "furigana";
    type Answer = Readings;
}

/// Japanese spoken in Mercury's voice (Triton's DJ).
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Say {
    pub text: String,
}

/// Where the WAV of it is, in Mercury's cache.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Spoken {
    pub path: String,
}

impl Ask for Say {
    const WORLD: &'static str = "mercury";
    const ID: &'static str = "say";
    type Answer = Spoken;
}

/// How much Japanese the person reads (how the DJ speaks to them).
#[derive(Clone, Copy, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Level;

/// 1 while hiragana is being learned, 2 with fewer than 150 words, 3
/// after; and the figures it comes from.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Known {
    pub level: u8,
    /// Basic hiragana met, of all there are.
    pub hiragana: u32,
    pub of: u32,
    /// Cards learned.
    pub learned: u32,
}

impl Ask for Level {
    const WORLD: &'static str = "mercury";
    const ID: &'static str = "level";
    type Answer = Known;
}

/// A word to learn, into Mercury's "From songs" deck: the word, its entry
/// in the dictionary when the asker knows it, and the line it was heard in.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct AddWord {
    pub word: String,
    #[serde(default)]
    pub entry: Option<i64>,
    #[serde(default)]
    pub line: String,
}

impl Tell for AddWord {
    const WORLD: &'static str = "mercury";
    const ID: &'static str = "add-word";
    fn arg(&self) -> Option<String> {
        serde_json::to_string(self).ok()
    }
    /// The JSON Neptune sends, or a word alone (`--do add-word 猫`).
    fn read(arg: Option<&str>) -> Result<Self, String> {
        let arg = arg.unwrap_or_default();
        if arg.trim_start().starts_with('{') {
            serde_json::from_str(arg).map_err(|e| format!("that word didn't read: {e}"))
        } else {
            Ok(Self {
                word: arg.trim().to_owned(),
                ..Self::default()
            })
        }
    }
}

/// What sounds now in Neptune (Triton's DJ, between tracks).
#[derive(Clone, Copy, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Now;

/// The player as it is: nothing but `stopped` while the queue is empty.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Playing {
    /// `playing`, `paused` or `stopped`.
    pub state: String,
    pub id: Option<String>,
    pub title: Option<String>,
    pub artist: Option<String>,
    /// Seconds into the track.
    pub position: Option<f64>,
    /// The track's length in seconds.
    pub duration: Option<u32>,
}

impl Ask for Now {
    const WORLD: &'static str = "neptune";
    const ID: &'static str = "now";
    type Answer = Playing;
}

/// The music lowered under a voice: to `level` of the volume, for `ms`.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct Duck {
    #[serde(default = "Duck::usual_level")]
    pub level: f64,
    #[serde(default = "Duck::usual_ms")]
    pub ms: u64,
}

impl Duck {
    fn usual_level() -> f64 {
        0.3
    }
    fn usual_ms() -> u64 {
        5000
    }
}

impl Default for Duck {
    fn default() -> Self {
        Self {
            level: Self::usual_level(),
            ms: Self::usual_ms(),
        }
    }
}

impl Tell for Duck {
    const WORLD: &'static str = "neptune";
    const ID: &'static str = "duck";
    fn arg(&self) -> Option<String> {
        serde_json::to_string(self).ok()
    }
    /// What doesn't read is the usual duck.
    fn read(arg: Option<&str>) -> Result<Self, String> {
        Ok(arg
            .and_then(|a| serde_json::from_str(a).ok())
            .unwrap_or_default())
    }
}

/// The music paused, never started (Luna, at the end of a wind-down).
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Pause;

impl Tell for Pause {
    const WORLD: &'static str = "neptune";
    const ID: &'static str = "pause";
    fn arg(&self) -> Option<String> {
        None
    }
    fn read(_: Option<&str>) -> Result<Self, String> {
        Ok(Pause)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_wire_is_as_it_was() {
        // What the askers sent before these types.
        fn sent<Q: Ask>(q: &Q) -> Value {
            serde_json::to_value(q).unwrap()
        }
        assert_eq!(
            sent(&Furigana {
                lines: vec!["夜".into()]
            }),
            serde_json::json!({ "lines": ["夜"] })
        );
        assert_eq!(sent(&Level), Value::Null);
        assert_eq!(sent(&Now), Value::Null);
        assert_eq!(
            sent(&Say {
                text: "ラジオ".into()
            }),
            serde_json::json!({ "text": "ラジオ" })
        );
        let duck: Value = serde_json::from_str(
            &Duck {
                level: 0.3,
                ms: 2400,
            }
            .arg()
            .unwrap(),
        )
        .unwrap();
        assert_eq!(duck, serde_json::json!({ "level": 0.3, "ms": 2400 }));
        assert_eq!(Duck::read(None), Ok(Duck::default()));
        assert_eq!(Duck::read(Some(r#"{"ms":100}"#)).unwrap().level, 0.3);
        assert_eq!(Pause.arg(), None);
        let word: Value = serde_json::from_str(
            &AddWord {
                word: "夜".into(),
                entry: None,
                line: "夜の街".into(),
            }
            .arg()
            .unwrap(),
        )
        .unwrap();
        assert_eq!(
            word,
            serde_json::json!({ "word": "夜", "entry": null, "line": "夜の街" })
        );
        assert_eq!(AddWord::read(Some(" 猫 ")).unwrap().word, "猫");
        assert!(AddWord::read(Some("{nope")).is_err());
        // A word with no reading of its own says nothing of one.
        let plain = serde_json::to_value(Part {
            base: "の".into(),
            rt: None,
        })
        .unwrap();
        assert_eq!(plain, serde_json::json!({ "base": "の" }));
    }
}
