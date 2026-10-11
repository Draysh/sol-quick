//! For a world's tests (`sol_quick::testing`, always there: nothing here
//! runs unless a test calls it, and no feature means the kit is built once
//! for the app and its tests alike):
//!
//! - [`offline_link`]: a `Link` with a local copy and no Sol.
//! - [`assert_manifest`]: `sol-world.json` is sound and says what the code
//!   does (the actions, events, settings and collections in an [`Expect`]),
//!   with the rules every world shares checked too.
//! - [`capture_q`]: the question quick capture asks a world's `ask` command.
//! - [`assert_asked`], [`assert_told`], [`assert_copy`]: a question's
//!   fixture (`fixtures/questions/<id>.json`) reads as the kit's types, and
//!   an asker's copy is the answerer's own.
//! - [`undoably`], [`take_back`]: a write run as `Sol.undoable` runs it,
//!   and its notice's Undo.
//! - [`FakeDoor`]: another world's running app, answering through its door,
//!   for a world that asks another (`questions::ask`, `questions::tell`).
//! - orbit's stand-ins, re-exported: [`FakeHttp`], [`Reply`], [`Request`],
//!   [`Requests`], [`StandInSol`].
//!
//! Outside `sol_quick::run` every door (`sol-<world>`) is the process's own
//! (`sol-test-<pid>-<world>`), so a test never reaches an app running on the
//! computer.

use std::{
    collections::BTreeSet,
    path::{Path, PathBuf},
    sync::{
        Arc, Condvar, Mutex,
        atomic::{AtomicBool, Ordering},
    },
    thread::JoinHandle,
};

pub use orbit::testing::{
    FakeHttp, Reply, Request, Requests, StandInSol, open, paired_with, person, puts,
};
use orbit::{WorldManifest, link::Link};
use serde_json::Value;

use crate::{
    door::Question,
    single::{Answer, Knock, open_door, wake_door},
};

/// A link for `world` with a local copy in a fresh folder and no Sol, as an
/// app that was never paired. Keep the folder for as long as the link.
pub async fn offline_link(world: &str) -> (Link, tempfile::TempDir) {
    orbit::testing::offline(world).await
}

/// Runs `command` as `Sol.undoable` does (the kit's `undoable`): its
/// reply, and the token Undo sends back (None for a command that keeps
/// no documents). A failed write panics with its sentence.
pub async fn undoably(
    commands: &crate::Commands,
    link: &Link,
    command: &str,
    args: Value,
) -> (Value, Option<u64>) {
    let args = serde_json::json!({ "command": command, "args": args });
    let reply = commands.call(link.clone(), "undoable", args).await;
    let reply: Value =
        serde_json::from_str(&reply.unwrap_or_else(|why| panic!("{command}: {why}")))
            .expect("the reply is JSON");
    (reply["result"].clone(), reply["undo"].as_u64())
}

/// The notice's Undo for a write [`undoably`] ran: its documents put back
/// as they were.
pub async fn take_back(link: &Link, token: u64) {
    let before = crate::undo::take(token).expect("the write is kept for Undo");
    let theirs: Vec<String> = before.iter().map(|b| b.collection.clone()).collect();
    crate::undo::restore(link, &before, &theirs)
        .await
        .expect("the documents go back");
}

/// What a manifest must list for the code: ids of actions, kinds of events,
/// keys of settings and ids of collections, and the planet of a moon.
#[derive(Clone, Debug, Default)]
pub struct Expect<'a> {
    pub parent: Option<&'a str>,
    pub actions: &'a [&'a str],
    pub emits: &'a [&'a str],
    pub settings: &'a [&'a str],
    pub collections: &'a [&'a str],
}

/// Checks a world's `sol-world.json` (`MANIFEST`, its text) and hands it
/// back for the world's own checks:
///
/// - it parses and `problems()` finds none;
/// - everything in `expect` is listed;
/// - a `day_starts` setting defaults to the day orbit starts while Sol has
///   sent none (`DEFAULT_DAY_STARTS`, 04:00);
/// - a world whose screens play a moment (`moment.play(` in `qml/`) lists
///   the `moments` collection;
/// - Sol's hand copy, `../../hub/catalog/<id>.json`, says the same, when the
///   world sits in the workspace checkout beside the hub.
pub fn assert_manifest(manifest: &str, expect: Expect) -> WorldManifest {
    let m: WorldManifest = serde_json::from_str(manifest).expect("sol-world.json parses");
    assert!(m.problems().is_empty(), "{:?}", m.problems());
    if let Some(parent) = expect.parent {
        assert_eq!(m.parent.as_deref(), Some(parent), "the planet of a moon");
    }
    for action in expect.actions {
        assert!(
            m.action(action).is_some(),
            "the action {action} isn't listed"
        );
    }
    for kind in expect.emits {
        assert!(m.emitted(kind).is_some(), "the event {kind} isn't listed");
    }
    for key in expect.settings {
        assert!(
            m.settings.iter().any(|s| s.key == *key),
            "the setting {key} is read by the code"
        );
    }
    let lists = |id: &str| m.collections.iter().any(|c| c.id == id);
    for id in expect.collections {
        assert!(lists(id), "the collection {id} isn't listed");
    }
    if let Some(day) = m
        .settings
        .iter()
        .find(|s| s.key == orbit::clock::DAY_STARTS)
    {
        let default = day.default.as_ref().and_then(|d| d.as_str());
        assert_eq!(
            default.and_then(orbit::clock::parse_time),
            Some(orbit::clock::DEFAULT_DAY_STARTS),
            "day_starts defaults to the day an unset setting gets"
        );
    }
    let here = world_dir();
    if plays_moments(&here.join("qml")) {
        assert!(
            lists(crate::moments::MOMENTS),
            "the screens play moments, so the manifest lists the moments collection"
        );
    }
    let catalog = here.join(format!("../../hub/catalog/{}.json", m.id));
    if let Ok(copy) = std::fs::read_to_string(&catalog) {
        let copy: Value = serde_json::from_str(&copy).expect("the catalog copy parses");
        let ours: Value = serde_json::from_str(manifest).expect("sol-world.json parses");
        assert_eq!(
            copy,
            ours,
            "{} differs from sol-world.json: copy it there",
            catalog.display()
        );
    }
    m
}

/// The folder of the world under test: the nearest folder up from the crate
/// being tested (cargo runs tests from there) with a `sol-world.json`, so a
/// world's logic crate in `crates/<world>-core` finds its world's root.
fn world_dir() -> PathBuf {
    let start = std::env::var_os("CARGO_MANIFEST_DIR")
        .map(PathBuf::from)
        .or_else(|| std::env::current_dir().ok())
        .unwrap_or_default();
    start
        .ancestors()
        .find(|dir| dir.join("sol-world.json").is_file())
        .map_or(start.clone(), Path::to_path_buf)
}

/// Whether any screen in `qml` plays a moment.
fn plays_moments(qml: &Path) -> bool {
    let Ok(files) = std::fs::read_dir(qml) else {
        return false;
    };
    files.flatten().any(|f| {
        f.path().extension().is_some_and(|e| e == "qml")
            && std::fs::read_to_string(f.path()).is_ok_and(|text| text.contains("moment.play("))
    })
}

/// What quick capture asks a world's `ask` command about `line`: what it
/// would do, or with `go`, to do it.
pub fn capture_q(line: &str, go: bool) -> Question {
    Question {
        id: "capture".into(),
        arg: serde_json::json!({ "line": line, "go": go }),
    }
}

/// A question's fixture, `{ "arg": …, "answer": … }` (the wire as it was
/// asked and answered): both read as the kit's types and are written back
/// the same, so the wire stays what installed apps of other versions speak.
pub fn assert_asked<Q: crate::questions::Ask>(fixture: &str) -> (Q, Q::Answer) {
    let f: Value = serde_json::from_str(fixture).expect("the fixture parses");
    let arg = f.get("arg").cloned().unwrap_or(Value::Null);
    let q: Q = serde_json::from_value(arg.clone())
        .unwrap_or_else(|e| panic!("{}'s question doesn't read: {e}", Q::ID));
    assert_eq!(
        serde_json::json!(&q),
        arg,
        "{}'s question is written back the same",
        Q::ID
    );
    let answer: Q::Answer = serde_json::from_value(f["answer"].clone())
        .unwrap_or_else(|e| panic!("{}'s answer doesn't read: {e}", Q::ID));
    assert_eq!(
        serde_json::json!(&answer),
        f["answer"],
        "{}'s answer is written back the same",
        Q::ID
    );
    (q, answer)
}

/// The fixture of something told, `{ "arg": "<text>" | null, "answer":
/// "<sentence>" }`: the argument reads as the kit's type and is sent the
/// same (as JSON, when it is JSON).
pub fn assert_told<T: crate::questions::Tell>(fixture: &str) -> T {
    let f: Value = serde_json::from_str(fixture).expect("the fixture parses");
    let arg = f["arg"].as_str().map(str::to_owned);
    let told = T::read(arg.as_deref())
        .unwrap_or_else(|e| panic!("{}'s argument doesn't read: {e}", T::ID));
    let json = |a: &Option<String>| a.as_deref().map(|t| serde_json::from_str::<Value>(t).ok());
    let sent = told.arg();
    match (json(&arg), json(&sent)) {
        (Some(Some(a)), Some(Some(s))) => assert_eq!(a, s, "{}'s argument is sent the same", T::ID),
        _ => assert_eq!(arg, sent, "{}'s argument is sent the same", T::ID),
    }
    assert!(f["answer"].is_string(), "{} answers a sentence", T::ID);
    told
}

/// An asker's copy of another world's fixture (`ours`, its text) is that
/// world's own, at `theirs` from this world's folder
/// (`../mercury/fixtures/questions/furigana.json`), when it sits beside
/// this one, as in the workspace checkout.
pub fn assert_copy(ours: &str, theirs: &str) {
    let path = world_dir().join(theirs);
    if let Ok(text) = std::fs::read_to_string(&path) {
        assert_eq!(text, ours, "copy {} here", path.display());
    }
}

/// The worlds whose fake door is open: tests run side by side, and two
/// fakes of one world can't share its door, so the second waits for the
/// first to close (fakes of different worlds open at once).
static OPEN: Mutex<BTreeSet<String>> = Mutex::new(BTreeSet::new());
static CLOSED: Condvar = Condvar::new();

/// Another world's app, running as far as this process can tell: its door
/// answers each `ask`, `do` and `find` with `answer(command, args)` (`Ok`
/// the reply, `Err` the "no" with why) and keeps what it was asked. It stops
/// answering when dropped.
pub struct FakeDoor {
    world: String,
    stop: Arc<AtomicBool>,
    asked: Arc<Mutex<Vec<(String, Value)>>>,
    door: Option<JoinHandle<()>>,
}

impl FakeDoor {
    pub fn open(
        world: &str,
        answer: impl Fn(&str, &Value) -> Result<Value, String> + Send + Sync + 'static,
    ) -> Self {
        let mut open = OPEN.lock().unwrap_or_else(|e| e.into_inner());
        while open.contains(world) {
            open = CLOSED.wait(open).unwrap_or_else(|e| e.into_inner());
        }
        open.insert(world.to_owned());
        drop(open);
        let stop = Arc::new(AtomicBool::new(false));
        let asked: Arc<Mutex<Vec<(String, Value)>>> = Arc::default();
        let kept = asked.clone();
        let on_knock: Arc<dyn Fn(Knock) -> Answer + Send + Sync> =
            Arc::new(move |knock: Knock| -> Answer {
                let Knock::Ask(command, args) = knock else {
                    return None;
                };
                kept.lock()
                    .unwrap_or_else(|e| e.into_inner())
                    .push((command.clone(), args.clone()));
                Some(answer(&command, &args).map(|reply| reply.to_string()))
            });
        // The fake before it closed its door before it let go of the world.
        let door = match open_door(world, stop.clone(), on_knock) {
            Ok(door) => door,
            Err(e) => {
                closed(world);
                panic!("no door for {world}: {e}");
            }
        };
        Self {
            world: world.to_owned(),
            stop,
            asked,
            door: Some(door),
        }
    }

    /// Every command asked so far, with its arguments, in order:
    /// `("ask", {"id": "furigana", …})`, `("do", {"id": "pause", …})`.
    pub fn asked(&self) -> Vec<(String, Value)> {
        self.asked.lock().unwrap_or_else(|e| e.into_inner()).clone()
    }
}

impl Drop for FakeDoor {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::SeqCst);
        wake_door(&self.world);
        if let Some(door) = self.door.take() {
            let _ = door.join();
        }
        closed(&self.world);
    }
}

/// The world's fake door is closed: the next fake of it may open.
fn closed(world: &str) {
    OPEN.lock().unwrap_or_else(|e| e.into_inner()).remove(world);
    CLOSED.notify_all();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_fake_door_answers_another_worlds_questions() {
        let door = FakeDoor::open("exoplanet", |command, args| match command {
            "ask" => Ok(serde_json::json!({ "asked": args["id"] })),
            _ => Err("not that".into()),
        });
        let said = crate::door::ask("exoplanet", "furigana", serde_json::json!({ "lines": [] }));
        assert_eq!(said, Ok(serde_json::json!({ "asked": "furigana" })));
        assert_eq!(
            crate::door::tell("exoplanet", "add-word", None),
            Err(crate::door::Unanswered::No("not that".into()))
        );
        let asked = door.asked();
        assert_eq!(asked.len(), 2);
        assert_eq!(asked[1].0, "do");
        drop(door);
        // Gone at once: nobody answers (no other test fakes this world), and
        // no app running here was ever asked.
        assert_eq!(
            crate::door::ask("exoplanet", "furigana", Value::Null),
            Err(crate::door::Unanswered::NotRunning)
        );
    }

    #[test]
    fn capture_questions_carry_their_line() {
        let line = crate::capture::line_of(&capture_q("walk", true)).unwrap();
        assert_eq!((line.line.as_str(), line.go), ("walk", true));
    }

    #[tokio::test]
    async fn every_question_goes_through_a_door_with_its_type() {
        use crate::questions::*;
        let door = FakeDoor::open("mercury", |command, args| {
            Ok(match (command, args["id"].as_str()) {
                ("ask", Some("furigana")) => {
                    serde_json::json!({ "lines": [[{ "parts": [{ "base": "夜", "rt": "よる" }], "word": "夜", "entry": 1 }]] })
                }
                ("ask", Some("say")) => serde_json::json!({ "path": "/tmp/a.wav" }),
                ("ask", Some("level")) => {
                    serde_json::json!({ "level": 2, "hiragana": 46, "of": 46, "learned": 12 })
                }
                ("do", Some("add-word")) => serde_json::json!("Added 夜 to From songs."),
                _ => return Err("not that".into()),
            })
        });
        let readings = ask(Furigana {
            lines: vec!["夜".into()],
        })
        .await
        .unwrap();
        assert_eq!(readings.lines[0][0].parts[0].rt.as_deref(), Some("よる"));
        assert_eq!(
            ask(Say { text: "夜".into() }).await.unwrap().path,
            "/tmp/a.wav"
        );
        assert_eq!(ask(Level).await.unwrap().level, 2);
        let word = AddWord {
            word: "夜".into(),
            entry: Some(1),
            line: "夜の街".into(),
        };
        assert_eq!(tell(word).await.unwrap(), "Added 夜 to From songs.");
        let asked = door.asked();
        assert_eq!(
            asked[0].1,
            serde_json::json!({ "id": "furigana", "arg": { "lines": ["夜"] } })
        );
        assert_eq!(
            asked[2].1,
            serde_json::json!({ "id": "level", "arg": null })
        );
        assert_eq!(
            asked[3].1["arg"],
            r#"{"word":"夜","entry":1,"line":"夜の街"}"#
        );
        drop(door);

        let door = FakeDoor::open("neptune", |command, args| {
            Ok(match (command, args["id"].as_str()) {
                ("ask", Some("now")) => {
                    serde_json::json!({ "state": "playing", "id": "tr-1-1", "title": "Bright Static", "artist": "Kaito Mori", "position": 2.5, "duration": 362 })
                }
                ("do", Some("duck")) => serde_json::json!("Lowered for 2 seconds."),
                ("do", Some("pause")) => serde_json::json!("Paused “Bright Static”."),
                _ => return Err("not that".into()),
            })
        });
        let now = ask(Now).await.unwrap();
        assert_eq!((now.state.as_str(), now.duration), ("playing", Some(362)));
        assert_eq!(
            tell(Duck {
                level: 0.3,
                ms: 2000
            })
            .await
            .unwrap(),
            "Lowered for 2 seconds."
        );
        assert_eq!(tell(Pause).await.unwrap(), "Paused “Bright Static”.");
        let asked = door.asked();
        assert_eq!(asked[1].1["arg"], r#"{"level":0.3,"ms":2000}"#);
        assert_eq!(
            asked[2].1,
            serde_json::json!({ "id": "pause", "arg": null })
        );
        drop(door);
        // Nobody there (no other test fakes Neptune): the asker does without.
        assert_eq!(ask(Now).await, Err(crate::door::Unanswered::NotRunning));
    }

    #[test]
    fn fixtures_read_as_the_kits_types() {
        let (q, a) = assert_asked::<crate::questions::Furigana>(
            r#"{ "arg": { "lines": ["夜"] }, "answer": { "lines": [[{ "parts": [{ "base": "夜", "rt": "よる" }] }]] } }"#,
        );
        assert_eq!((q.lines.len(), a.lines.len()), (1, 1));
        let duck = assert_told::<crate::questions::Duck>(
            r#"{ "arg": "{\"ms\":2400,\"level\":0.3}", "answer": "Lowered for 2 seconds." }"#,
        );
        assert_eq!(duck.ms, 2400);
        assert_told::<crate::questions::Pause>(
            r#"{ "arg": null, "answer": "Nothing is playing." }"#,
        );
        assert_copy("anything", "no/such/world.json");
    }
}
