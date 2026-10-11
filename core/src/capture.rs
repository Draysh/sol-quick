//! Quick capture: one line typed over the desktop ("walk", "watched",
//! "slept 7.5", "radio frieren"), done by whichever running world
//! understands it. A key on the desktop knocks on any running world's door
//! (`ask capture`), and that app opens the line (`assets/capture/Capture.qml`,
//! a layer-shell window). As the person types, every running world is asked
//! through its door what it would do with the line (its `ask` command,
//! question `capture`, [`Line`] → [`Offer`] or null), at most
//! [`BUDGET`] each; the best offer is shown before Enter, and Enter has
//! that world do it (the same question with `go`, answered with one
//! sentence). Nothing here starts an app: a world that isn't running is
//! named as such.

use std::time::Duration;

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::{app::runtime, door::Question, single};

/// How long a world has to say what it would do with a line.
pub const BUDGET: Duration = Duration::from_millis(100);
/// How long it has to do it.
const DOING: Duration = Duration::from_secs(8);

/// What a world is asked about a line (`Question { id: "capture", arg }`).
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct Line {
    pub line: String,
    /// Do it now (Enter), rather than say what would be done.
    #[serde(default)]
    pub go: bool,
}

/// What a world would do with a line: "tick Walk", and how sure it is
/// (1 an exact name, 0.5 a word it knows, less for a guess).
#[derive(Clone, Debug, Default, PartialEq, Deserialize, Serialize)]
pub struct Offer {
    pub does: String,
    #[serde(default)]
    pub sure: f64,
}

impl Offer {
    pub fn new(does: impl Into<String>, sure: f64) -> Self {
        Self {
            does: does.into(),
            sure,
        }
    }
}

/// One world's offer, as the line shows it.
#[derive(Clone, Debug, Serialize)]
pub struct Answer {
    pub world: String,
    pub name: String,
    pub does: String,
    pub sure: f64,
}

/// Every running world's offer for a line, best first, and the worlds
/// installed here that aren't running.
#[derive(Clone, Debug, Default, Serialize)]
pub struct Offers {
    pub answers: Vec<Answer>,
    pub away: Vec<String>,
}

/// A world's name from its id: `terra` → Terra.
pub fn name_of(world: &str) -> String {
    let mut c = world.chars();
    c.next()
        .map(|f| f.to_uppercase().collect::<String>() + c.as_str())
        .unwrap_or_default()
}

/// The worlds to ask: those installed here, and this one.
fn worlds() -> Vec<String> {
    let me = runtime().app.world.to_owned();
    let mut all = orbit::doors::installed();
    all.retain(|w| w != "sol");
    if !all.contains(&me) {
        all.push(me);
    }
    all.sort();
    all.dedup();
    all
}

/// What one world says, this app's own straight from its commands.
async fn ask_one(world: String, line: Line, wait: Duration) -> Result<Value, Option<String>> {
    let rt = runtime();
    let question = Question {
        id: "capture".into(),
        arg: serde_json::json!(line),
    };
    if world == rt.app.world {
        if !rt.commands.has("ask") {
            return Ok(Value::Null);
        }
        let call = rt
            .commands
            .call(rt.link.clone(), "ask", serde_json::json!(question));
        return match tokio::time::timeout(wait, call).await {
            Ok(Ok(text)) => Ok(serde_json::from_str(&text).unwrap_or(Value::Null)),
            Ok(Err(why)) => Err(Some(why)),
            Err(_) => Ok(Value::Null),
        };
    }
    let preview = rt.preview;
    let asked = tokio::task::spawn_blocking(move || {
        single::ask_within(&world, preview, "ask", &serde_json::json!(question), wait)
    })
    .await
    .unwrap_or(single::Asked::Nobody);
    match asked {
        single::Asked::Yes(text) => Ok(serde_json::from_str(&text).unwrap_or(Value::Null)),
        single::Asked::Nobody => Err(None),
        // Older, or no `ask` command, or no answer in time: nothing to offer.
        single::Asked::No(_) | single::Asked::Old => Ok(Value::Null),
    }
}

/// Every running world's offer for `line`.
pub(crate) async fn offers(line: &str) -> Offers {
    let line = line.trim().to_owned();
    let mut out = Offers::default();
    let mut asks = tokio::task::JoinSet::new();
    for world in worlds() {
        let asked = Line {
            line: line.clone(),
            go: false,
        };
        asks.spawn(async move { (world.clone(), ask_one(world, asked, BUDGET).await) });
    }
    while let Some(done) = asks.join_next().await {
        let Ok((world, said)) = done else { continue };
        match said {
            Ok(value) => {
                if let Ok(offer) = serde_json::from_value::<Offer>(value)
                    && !offer.does.is_empty()
                    && !line.is_empty()
                {
                    out.answers.push(Answer {
                        name: name_of(&world),
                        world,
                        does: offer.does,
                        sure: offer.sure,
                    });
                }
            }
            Err(None) => out.away.push(name_of(&world)),
            Err(Some(_)) => {}
        }
    }
    rank(&mut out);
    out
}

/// Best first; between equals, by name, so the line doesn't flicker.
fn rank(out: &mut Offers) {
    out.answers.sort_by(|a, b| {
        b.sure
            .partial_cmp(&a.sure)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| a.name.cmp(&b.name))
    });
    out.away.sort();
}

/// Has `world` do `line`, and says what it did.
pub(crate) async fn run(world: &str, line: &str) -> Result<String, String> {
    let asked = Line {
        line: line.trim().to_owned(),
        go: true,
    };
    match ask_one(world.to_owned(), asked, DOING).await {
        Ok(Value::String(said)) => Ok(said),
        Ok(_) => Ok("Done.".into()),
        Err(None) => Err(format!("{} isn't running.", name_of(world))),
        Err(Some(why)) => Err(why),
    }
}

/// The first word, lowercased, and the rest as typed:
/// "Watched Frieren 8" → ("watched", "Frieren 8").
pub fn verb(line: &str) -> (String, &str) {
    let line = line.trim();
    match line.split_once(char::is_whitespace) {
        Some((first, rest)) => (first.to_lowercase(), rest.trim()),
        None => (line.to_lowercase(), ""),
    }
}

/// For a world's `ask` command: the line it was handed, when the question
/// is `capture`.
pub fn line_of(question: &Question) -> Option<Line> {
    (question.id == "capture")
        .then(|| serde_json::from_value(question.arg.clone()).ok())
        .flatten()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_best_offer_comes_first() {
        let a = |name: &str, sure| Answer {
            world: name.to_lowercase(),
            name: name.into(),
            does: "x".into(),
            sure,
        };
        let mut out = Offers {
            answers: vec![a("Saturn", 0.5), a("Terra", 1.0), a("Neptune", 0.5)],
            away: vec!["Mercury".into(), "Luna".into()],
        };
        rank(&mut out);
        let names: Vec<_> = out.answers.iter().map(|a| a.name.as_str()).collect();
        assert_eq!(names, ["Terra", "Neptune", "Saturn"]);
        assert_eq!(out.away, ["Luna", "Mercury"]);
    }

    #[test]
    fn a_capture_question_carries_its_line() {
        let q = Question {
            id: "capture".into(),
            arg: serde_json::json!({ "line": "walk", "go": true }),
        };
        let line = line_of(&q).unwrap();
        assert_eq!(line.line, "walk");
        assert!(line.go);
        let other = Question {
            id: "furigana".into(),
            arg: Value::Null,
        };
        assert!(line_of(&other).is_none());
        assert_eq!(name_of("terra"), "Terra");
        assert_eq!(
            verb("  Watched Frieren 8 "),
            ("watched".into(), "Frieren 8")
        );
        assert_eq!(verb("walk"), ("walk".into(), ""));
    }
}
