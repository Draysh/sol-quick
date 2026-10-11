//! The desktop around the app: what a world shows and does there without
//! a window, and the desktop's own services.
//!
//! A world says it all once, in a [`Desktop`], and the kit registers the
//! commands the desktop and the other worlds reach through its door
//! (`status`, `do`, `find`, `ask`), routes each action and question by its
//! id, and answers quick capture: every verb whose words start the line is
//! read, the surest plan is offered (`matching` has the one scale), and
//! with Enter that plan is run and its sentence said.
//!
//! ```ignore
//! pub fn desktop() -> Desktop {
//!     Desktop::new("Terra")
//!         .status(|link| async move { status(&link).await })
//!         .action("tick", |link, habit| async move { tick(&link, habit).await })
//!         .verb(&["slept", "sleep"], slept)
//!         .verb(&[], tick_by_name)
//! }
//! // main.rs: world::desktop::desktop().register(&mut commands);
//!
//! /// "slept 7.5": last night's sleep on this morning's page.
//! async fn slept(link: Link, typed: Typed) -> anyhow::Result<Option<Plan>> {
//!     let Some(hours) = hours(&typed.rest) else { return Ok(None) };
//!     Ok(Some(Plan::new(format!("slept {hours} h last night"), matching::VERB, async move {
//!         log_sleep(&link, hours).await?;
//!         anyhow::Ok(format!("Slept {hours} h last night."))
//!     })))
//! }
//! ```
//!
//! The desktop's services are here too: notifications, the file picker
//! and global shortcuts through the portal.

pub mod matching;
mod portal;

use std::{fmt::Display, future::Future, pin::Pin, sync::Arc};

use orbit::link::Link;
use serde::Serialize;
use serde_json::Value;

#[doc(hidden)]
pub use portal::start;
pub use portal::{Shortcut, TrayItem, notify, pick_file};

pub use crate::door::{Do, Found, Query, Question};
use crate::{
    capture::{self, Offer},
    commands::{Commands, say},
    questions::{Ask, Tell},
};

type Boxed<T> = Pin<Box<dyn Future<Output = Result<T, String>> + Send>>;
type Reads<A, T> = Arc<dyn Fn(Link, A) -> Boxed<T> + Send + Sync>;

/// A future's error as one sentence.
fn boxed<T, E: Display>(f: impl Future<Output = Result<T, E>> + Send + 'static) -> Boxed<T> {
    Box::pin(async move { f.await.map_err(say) })
}

/// JSON text, as the commands answer (an `f32` stays as written).
fn text(value: &impl Serialize) -> Result<String, String> {
    serde_json::to_string(value).map_err(say)
}

/// A line as a verb reads it: as typed, its first word lowercased, and the rest.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Typed {
    /// The whole line, trimmed.
    pub line: String,
    /// Its first word, lowercased: "watched".
    pub verb: String,
    /// What follows it, trimmed, as typed: "Frieren 8".
    pub rest: String,
}

impl Typed {
    pub fn of(line: &str) -> Self {
        let (verb, rest) = capture::verb(line);
        Self {
            line: line.trim().to_owned(),
            verb,
            rest: rest.to_owned(),
        }
    }
}

/// What a verb would do with a line: what it says it would do ("tick
/// Walk"), how sure it is (`matching`'s scale), and the doing, run only
/// when the person presses Enter. Do nothing before the run: an offer is
/// asked for on every key.
pub struct Plan {
    pub does: String,
    pub sure: f64,
    run: Boxed<String>,
}

impl Plan {
    /// `run` does it and says so in one sentence.
    pub fn new<E: Display>(
        does: impl Into<String>,
        sure: f64,
        run: impl Future<Output = Result<String, E>> + Send + 'static,
    ) -> Self {
        Self {
            does: does.into(),
            sure,
            run: boxed(run),
        }
    }

    /// Nothing to do but say so: "Walk is done today already".
    pub fn said(does: impl Into<String>, sure: f64, sentence: impl Into<String>) -> Self {
        let sentence = sentence.into();
        Self::new(does, sure, async move { Ok::<_, String>(sentence) })
    }

    /// Does it: the sentence to show.
    pub async fn run(self) -> Result<String, String> {
        self.run.await
    }
}

impl std::fmt::Debug for Plan {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Plan")
            .field("does", &self.does)
            .field("sure", &self.sure)
            .finish_non_exhaustive()
    }
}

/// A verb: the first words it answers to (none: every line, as Terra's
/// habit names), and how it reads a line.
#[derive(Clone)]
struct Verb {
    words: &'static [&'static str],
    read: Reads<Typed, Option<Plan>>,
}

/// Everything a world shows and does on the desktop, said once.
#[derive(Clone, Default)]
pub struct Desktop {
    name: &'static str,
    status: Option<Arc<dyn Fn(Link) -> Boxed<String> + Send + Sync>>,
    actions: Vec<(&'static str, Reads<Option<String>, String>)>,
    find: Option<Reads<String, Vec<Found>>>,
    questions: Vec<(&'static str, Reads<Value, String>)>,
    verbs: Vec<Verb>,
}

impl Desktop {
    /// `name` is the world's, for its sentences: "Terra can't answer …".
    pub fn new(name: &'static str) -> Self {
        Self {
            name,
            ..Self::default()
        }
    }

    /// The bar's status (`status`): a small object, cheap, nothing fetched.
    pub fn status<T, E, F, Fut>(mut self, f: F) -> Self
    where
        T: Serialize,
        E: Display,
        F: Fn(Link) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = Result<T, E>> + Send + 'static,
    {
        let f = Arc::new(f);
        self.status = Some(Arc::new(move |link| {
            let run = f(link);
            Box::pin(async move { text(&run.await.map_err(say)?) })
        }));
        self
    }

    /// An action from a key or the bar (`--do <id> [arg]`): one sentence on
    /// what it did.
    pub fn action<E, F, Fut>(mut self, id: &'static str, f: F) -> Self
    where
        E: Display,
        F: Fn(Link, Option<String>) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = Result<String, E>> + Send + 'static,
    {
        self.actions
            .push((id, Arc::new(move |link, arg| boxed(f(link, arg)))));
        self
    }

    /// What the launcher finds here (`--find <words>`), local only.
    pub fn find<E, F, Fut>(mut self, f: F) -> Self
    where
        E: Display,
        F: Fn(Link, String) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = Result<Vec<Found>, E>> + Send + 'static,
    {
        self.find = Some(Arc::new(move |link, query| boxed(f(link, query))));
        self
    }

    /// A verb for quick capture: `read` is called for a line whose first
    /// word is one of `words` (every line, with none), and answers what it
    /// would do, or None for a line that isn't its.
    pub fn verb<E, F, Fut>(mut self, words: &'static [&'static str], read: F) -> Self
    where
        E: Display,
        F: Fn(Link, Typed) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = Result<Option<Plan>, E>> + Send + 'static,
    {
        self.verbs.push(Verb {
            words,
            read: Arc::new(move |link, typed| boxed(read(link, typed))),
        });
        self
    }

    /// A question another world asks this one (`questions`).
    pub fn asked<Q, E, F, Fut>(mut self, f: F) -> Self
    where
        Q: Ask,
        E: Display,
        F: Fn(Link, Q) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = Result<Q::Answer, E>> + Send + 'static,
    {
        let f = Arc::new(f);
        self.questions.push((
            Q::ID,
            Arc::new(move |link, arg| {
                let f = f.clone();
                Box::pin(async move {
                    let q: Q = serde_json::from_value(arg)
                        .map_err(|e| format!("“{}” didn't read: {e}", Q::ID))?;
                    text(&f(link, q).await.map_err(say)?)
                })
            }),
        ));
        self
    }

    /// Something another world tells this one to do (`questions`), as an
    /// action: one sentence back.
    pub fn told<T, E, F, Fut>(self, f: F) -> Self
    where
        T: Tell,
        E: Display,
        F: Fn(Link, T) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = Result<String, E>> + Send + 'static,
    {
        let f = Arc::new(f);
        self.action(T::ID, move |link, arg: Option<String>| {
            let told = T::read(arg.as_deref());
            let f = f.clone();
            async move {
                match told {
                    Ok(told) => f(link, told).await.map_err(say),
                    Err(why) => Err(why),
                }
            }
        })
    }

    /// Every verb's words, in order (an empty list answers every line).
    pub fn words(&self) -> Vec<&'static [&'static str]> {
        self.verbs.iter().map(|v| v.words).collect()
    }

    /// Adds the commands the door reaches: `status`, `do`, `find` and
    /// `ask`, each only when there is something to answer.
    pub fn register<C: Send + 'static>(self, commands: &mut Commands<C>) {
        let me = Arc::new(self);
        if let Some(status) = me.status.clone() {
            commands.add_text("status", move |link, _| status(link));
        }
        if !me.actions.is_empty() {
            let d = me.clone();
            commands.add_linked("do", move |link, asked: Do| {
                let d = d.clone();
                async move { d.act(link, asked).await }
            });
        }
        if let Some(find) = me.find.clone() {
            commands.add_linked("find", move |link, q: Query| find(link, q.query));
        }
        if !me.questions.is_empty() || !me.verbs.is_empty() {
            let d = me.clone();
            commands.add_text("ask", move |link, args| {
                let d = d.clone();
                Box::pin(async move {
                    let asked: Question =
                        serde_json::from_value(args).map_err(|e| format!("bad arguments: {e}"))?;
                    d.answer(link, asked).await
                })
            });
        }
    }

    /// Runs an action (the `do` command): what it did, in one sentence.
    pub async fn act(&self, link: Link, asked: Do) -> Result<String, String> {
        match self.actions.iter().find(|(id, _)| *id == asked.id) {
            Some((_, run)) => run(link, asked.arg).await,
            None => {
                let ids: Vec<&str> = self.actions.iter().map(|(id, _)| *id).collect();
                Err(format!(
                    "{} can {}, not “{}”",
                    self.name,
                    or_list(&ids),
                    asked.id
                ))
            }
        }
    }

    /// Answers a question (the `ask` command), quick capture's too.
    pub async fn ask(&self, link: Link, asked: Question) -> Result<Value, String> {
        let reply = self.answer(link, asked).await?;
        serde_json::from_str(&reply).map_err(say)
    }

    /// Quick capture's question for `line`: an [`Offer`] (or null when no
    /// verb takes it), or with `go`, the sentence of it done.
    pub async fn capture(&self, link: Link, line: &str, go: bool) -> Result<Value, String> {
        let Some(plan) = self.plan(link, line).await? else {
            return Ok(Value::Null);
        };
        if !go {
            return Ok(serde_json::json!(Offer::new(plan.does, plan.sure)));
        }
        plan.run().await.map(Value::String)
    }

    /// The surest plan for `line` of every verb that takes its first word;
    /// between equals, the verb added first.
    pub async fn plan(&self, link: Link, line: &str) -> Result<Option<Plan>, String> {
        let typed = Typed::of(line);
        if typed.line.is_empty() {
            return Ok(None);
        }
        let mut best: Option<Plan> = None;
        for verb in &self.verbs {
            if !verb.words.is_empty() && !verb.words.contains(&typed.verb.as_str()) {
                continue;
            }
            if let Some(plan) = (verb.read)(link.clone(), typed.clone()).await?
                && best.as_ref().is_none_or(|b| plan.sure > b.sure)
            {
                best = Some(plan);
            }
        }
        Ok(best)
    }

    /// The `ask` command's reply, as JSON text.
    async fn answer(&self, link: Link, asked: Question) -> Result<String, String> {
        if let Some(line) = capture::line_of(&asked) {
            return text(&self.capture(link, &line.line, line.go).await?);
        }
        match self.questions.iter().find(|(id, _)| *id == asked.id) {
            Some((_, answer)) => answer(link, asked.arg).await,
            None => Err(format!("{} can't answer “{}”", self.name, asked.id)),
        }
    }
}

/// "a, b or c".
fn or_list(items: &[&str]) -> String {
    match items {
        [] => String::new(),
        [one] => (*one).to_owned(),
        [rest @ .., last] => format!("{} or {last}", rest.join(", ")),
    }
}

/// A value for a page's query (`/dictionary?query=…`), with what would
/// break it written as `%XX`, as the window's `decodeURIComponent` reads it.
pub fn encode(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for byte in value.bytes() {
        if byte.is_ascii_alphanumeric() || b"-_.~:".contains(&byte) {
            out.push(byte as char);
        } else {
            out.push_str(&format!("%{byte:02X}"));
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::questions::{Duck, Level};

    fn sample() -> Desktop {
        Desktop::new("Moon")
            .status(|_| async { Ok::<_, String>(serde_json::json!({ "left": 2 })) })
            .action("tick", |_, arg| async move {
                Ok::<_, String>(format!("Ticked {}.", arg.unwrap_or_default()))
            })
            .told(|_, duck: Duck| async move {
                Ok::<_, String>(format!("Lowered for {} ms.", duck.ms))
            })
            .asked(|_, _: Level| async {
                Ok::<_, String>(crate::questions::Known {
                    level: 2,
                    ..Default::default()
                })
            })
            .verb(&["walk"], |_, t: Typed| async move {
                Ok::<_, String>(Some(Plan::said(
                    format!("walk {}", t.rest),
                    matching::VERB,
                    "Walked.",
                )))
            })
            .verb(&[], |_, t: Typed| async move {
                Ok::<_, String>((t.line.len() > 3).then(|| {
                    Plan::new("say it back", matching::GUESS, async move {
                        Ok::<_, String>(format!("Said {}.", t.line))
                    })
                }))
            })
    }

    #[tokio::test]
    async fn one_desktop_answers_every_door_command() {
        let (link, _dir) = orbit::testing::offline("moon").await;
        let mut commands = Commands::default();
        sample().register(&mut commands);
        for name in ["status", "do", "ask"] {
            assert!(commands.has(name), "{name} is registered");
        }
        assert!(!commands.has("find"), "no find without one");
        let call = |name: &str, args: Value| commands.call(link.clone(), name, args);
        assert_eq!(call("status", Value::Null).await.unwrap(), r#"{"left":2}"#);
        assert_eq!(
            call("do", serde_json::json!({ "id": "tick", "arg": "walk" }))
                .await
                .unwrap(),
            r#""Ticked walk.""#
        );
        assert_eq!(
            call(
                "do",
                serde_json::json!({ "id": "duck", "arg": "{\"ms\":20}" })
            )
            .await
            .unwrap(),
            r#""Lowered for 20 ms.""#
        );
        assert_eq!(
            call("do", serde_json::json!({ "id": "dance" })).await,
            Err("Moon can tick or duck, not “dance”".into())
        );
        let level = call("ask", serde_json::json!({ "id": "level" }))
            .await
            .unwrap();
        assert_eq!(serde_json::from_str::<Value>(&level).unwrap()["level"], 2);
        assert_eq!(
            call("ask", serde_json::json!({ "id": "furigana" })).await,
            Err("Moon can't answer “furigana”".into())
        );
    }

    #[tokio::test]
    async fn the_surest_verb_is_offered_and_run_only_on_enter() {
        let (link, _dir) = orbit::testing::offline("moon").await;
        let d = sample();
        let q = |line: &str, go| crate::door::Question {
            id: "capture".into(),
            arg: serde_json::json!({ "line": line, "go": go }),
        };
        let offer = d.ask(link.clone(), q("Walk far", false)).await.unwrap();
        assert_eq!(
            offer,
            serde_json::json!({ "does": "walk far", "sure": 0.9 })
        );
        assert_eq!(
            d.ask(link.clone(), q("walk far", true)).await.unwrap(),
            "Walked."
        );
        let offer = d.ask(link.clone(), q("dance now", false)).await.unwrap();
        assert_eq!(offer["does"], "say it back");
        assert_eq!(
            d.capture(link.clone(), "dance now", true).await.unwrap(),
            "Said dance now."
        );
        assert!(
            d.capture(link.clone(), "hi", false)
                .await
                .unwrap()
                .is_null()
        );
        assert!(d.capture(link, "  ", false).await.unwrap().is_null());
        assert_eq!(d.words(), [&["walk"][..], &[][..]]);
    }

    #[test]
    fn small_words() {
        assert_eq!(or_list(&["tick"]), "tick");
        assert_eq!(or_list(&["a", "b", "c"]), "a, b or c");
        assert_eq!(encode("anime:21"), "anime:21");
        assert_eq!(encode("a b&c=d"), "a%20b%26c%3Dd");
        assert_eq!(encode("猫"), "%E7%8C%AB");
        let t = Typed::of("  Watched Frieren 8 ");
        assert_eq!((t.verb.as_str(), t.rest.as_str()), ("watched", "Frieren 8"));
        assert_eq!(t.line, "Watched Frieren 8");
    }
}
