//! The door from outside: what the desktop and the other worlds' apps on
//! this computer ask a running world through its single-instance door.
//!
//! - `--do <action> [argument]` runs the world's `do` command (a [`Do`] →
//!   one sentence on what it did), and `--find <words>` its `find` command
//!   (a [`Query`] → a list of [`Found`]); both print what the running copy
//!   answered.
//! - Another world's app asks while both run: [`ask`] puts a question to a
//!   world's `ask` command (a [`Question`] → any JSON) and [`tell`] runs its
//!   `do`. Neither starts the other app: when it isn't running the answer is
//!   [`Unanswered::NotRunning`], and the asker does without. The questions
//!   asked today have types of their own (`questions`).
//!
//! A world answers all of these through `desktop::Desktop`, which registers
//! the commands.

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::single::{self, Asked};

/// One answer to `--find`: what it is, and the page that shows it.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Found {
    /// The main line: an album, a title, a deck.
    pub title: String,
    /// The line under it: the artist, the year and kind, how many cards.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub subtitle: Option<String>,
    /// The page to open it at (`/title?key=anime:1`), for `--open`.
    pub open: String,
    /// What sort of thing it is, in a word ("album", "anime", "deck").
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub kind: Option<String>,
}

/// What `--do` hands the world's `do` command.
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct Do {
    /// The action: `play-pause`, `tick`, `start-evening`.
    pub id: String,
    /// What follows it on the command line, if anything (a habit's id).
    #[serde(default)]
    pub arg: Option<String>,
}

/// What [`ask`] hands the world's `ask` command: the question, and what
/// goes with it.
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct Question {
    /// What is asked: `furigana`.
    pub id: String,
    #[serde(default)]
    pub arg: Value,
}

/// What `--find` hands the world's `find` command.
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct Query {
    pub query: String,
}

/// Why another world gave no answer.
#[derive(Clone, Debug, PartialEq)]
pub enum Unanswered {
    /// It isn't running here.
    NotRunning,
    /// The copy running is older than the question.
    Old,
    /// It answered no, with why, in one sentence.
    No(String),
}

impl std::error::Error for Unanswered {}

impl std::fmt::Display for Unanswered {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Unanswered::NotRunning => f.write_str("it isn't running"),
            Unanswered::Old => f.write_str("the copy running is too old to answer"),
            Unanswered::No(why) => f.write_str(why),
        }
    }
}

impl Unanswered {
    /// What a terminal is told, naming the world: "Terra isn't running."
    fn told(&self, name: &str) -> String {
        match self {
            Unanswered::NotRunning => format!("{name} isn't running."),
            Unanswered::Old => {
                format!("The {name} running here is older than this; update it first.")
            }
            Unanswered::No(why) => why.clone(),
        }
    }
}

/// The door's answer: the reply as JSON text, or why there is none.
fn answered(asked: Asked) -> Result<String, Unanswered> {
    match asked {
        Asked::Yes(reply) => Ok(reply),
        Asked::No(why) => Err(Unanswered::No(why)),
        Asked::Old => Err(Unanswered::Old),
        Asked::Nobody => Err(Unanswered::NotRunning),
    }
}

/// Knocks with `command` and its arguments on the running copy of `world`.
fn knock(world: &str, preview: bool, command: &str, args: Value) -> Result<String, Unanswered> {
    answered(single::ask(world, preview, command, &args))
}

fn previewing() -> bool {
    std::env::var_os("SOL_PREVIEW").is_some()
}

/// A `do` command's reply as the sentence it is (nothing for a null).
fn sentence(reply: &str) -> String {
    match serde_json::from_str::<Value>(reply) {
        Ok(Value::String(said)) => said,
        _ => String::new(),
    }
}

/// Asks the running copy of `world` (the preview's, in a preview) a
/// question through its door, and waits for the answer (at most 20 s).
/// It blocks: call it off the async runtime (`spawn_blocking`), or use
/// `questions::ask` for a question with a type.
pub fn ask(world: &str, id: &str, arg: Value) -> Result<Value, Unanswered> {
    let question = Question {
        id: id.to_owned(),
        arg,
    };
    let reply = knock(world, previewing(), "ask", serde_json::json!(question))?;
    serde_json::from_str(&reply).map_err(|_| Unanswered::Old)
}

/// Has the running copy of `world` do something (its `do` command, as
/// `--do <id> <arg>` would), and says what it did. Blocks, as [`ask`] does.
pub fn tell(world: &str, id: &str, arg: Option<String>) -> Result<String, Unanswered> {
    let asked = Do {
        id: id.to_owned(),
        arg,
    };
    let reply = knock(world, previewing(), "do", serde_json::json!(asked))?;
    Ok(sentence(&reply))
}

/// `--do <action> [argument]`: asks the running copy to do it, and says
/// what it did.
pub(crate) fn act(world: &str, name: &str, preview: bool, args: &[String]) -> i32 {
    let Some((id, rest)) = args.split_first() else {
        eprintln!("Usage: --do <action> [argument]");
        return 2;
    };
    let asked = Do {
        id: id.clone(),
        arg: (!rest.is_empty()).then(|| rest.join(" ")),
    };
    match knock(world, preview, "do", serde_json::json!(asked)) {
        Ok(reply) => {
            match serde_json::from_str::<Value>(&reply) {
                Ok(Value::String(said)) => println!("{said}"),
                Ok(Value::Null) => {}
                _ => println!("{reply}"),
            }
            0
        }
        Err(why) => {
            eprintln!("{}", why.told(name));
            if why == Unanswered::NotRunning { 3 } else { 1 }
        }
    }
}

/// `--find <words>`: what the running copy finds for them, as a JSON list
/// with each answer's world beside it (`[]` when it isn't running).
pub(crate) fn find(world: &str, name: &str, preview: bool, args: &[String]) -> i32 {
    let query = Query {
        query: args.join(" "),
    };
    let found: Vec<Found> = match knock(world, preview, "find", serde_json::json!(query)) {
        Ok(reply) => serde_json::from_str(&reply).unwrap_or_default(),
        Err(why) => {
            eprintln!("{}", why.told(name));
            Vec::new()
        }
    };
    let rows: Vec<Value> = found
        .into_iter()
        .map(|f| {
            let mut v = serde_json::json!(f);
            v["world"] = world.into();
            v
        })
        .collect();
    println!("{}", Value::Array(rows));
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(target_os = "linux")]
    #[test]
    fn another_world_is_asked_through_its_door() {
        let world = format!("asked-{}", std::process::id());
        assert!(single::claim(&world, false, None, |k| match k {
            single::Knock::Ask(command, args) if command == "ask" => {
                let q: Question = serde_json::from_value(args).unwrap();
                Some(Ok(
                    serde_json::json!({ "id": q.id, "arg": q.arg }).to_string()
                ))
            }
            single::Knock::Ask(command, args) if command == "do" => {
                let d: Do = serde_json::from_value(args).unwrap();
                Some(Ok(serde_json::json!(format!("Did {}.", d.id)).to_string()))
            }
            _ => None,
        }));
        let answer = ask(&world, "furigana", serde_json::json!({ "lines": ["歌"] })).unwrap();
        assert_eq!(answer["id"], "furigana");
        assert_eq!(answer["arg"]["lines"][0], "歌");
        assert_eq!(tell(&world, "add-word", None).unwrap(), "Did add-word.");
        assert_eq!(
            ask(&format!("{world}-none"), "furigana", Value::Null),
            Err(Unanswered::NotRunning)
        );
        // The socket file older versions look for (another test may own the one `leave` removes).
        if let Some(dir) = dirs::runtime_dir() {
            let _ = std::fs::remove_file(dir.join(format!("sol-{world}.sock")));
        }
    }

    #[test]
    fn a_terminal_hears_why_in_the_worlds_name() {
        assert_eq!(Unanswered::NotRunning.told("Terra"), "Terra isn't running.");
        assert!(Unanswered::Old.told("Terra").contains("older than this"));
        assert_eq!(Unanswered::No("no habit".into()).told("Terra"), "no habit");
        assert_eq!(sentence("\"Ticked Walk.\""), "Ticked Walk.");
        assert_eq!(sentence("null"), "");
    }
}
