//! The commands a world's screens call. Each is an async function from
//! JSON arguments to a JSON reply (or one sentence on why not), named as
//! the screens name it: `Sol.call("tick_habit", { id, done: true })`.
//!
//! A world's module registers its own, next to the functions they call;
//! the arguments are the struct the closure takes (`()` for none), and an
//! error becomes the screens' sentence here (`say`):
//!
//! ```ignore
//! #[derive(Deserialize)]
//! struct Tick { id: String, done: bool }
//!
//! pub fn commands(c: &mut Commands) {
//!     c.add("list_habits", |link, ()| async move { habits(&link).await })
//!         .add("tick_habit", |link, a: Tick| async move { set_done(&link, &a.id, a.done).await })
//!         // Undo puts the habit back as it was.
//!         .undoable("archive_habit", |_, a: Id| async move { Ok(vec![doc(HABITS, &a.id)]) },
//!             |link, a: Id| async move { archive(&link, &a.id).await });
//! }
//! ```
//!
//! A world built around an engine gets it instead of the link
//! (`Commands::engine(&ENGINE)`: each command is handed `ENGINE.get()`).

use std::{collections::HashMap, future::Future, pin::Pin, sync::Arc};

use orbit::link::Link;
use serde::{Serialize, de::DeserializeOwned};
use serde_json::Value;

use crate::{
    engine::Shared,
    undo::{self, Before, Which},
};

/// What a command answers: its reply as JSON text, or one sentence on why not.
pub type Reply = Pin<Box<dyn Future<Output = Result<String, String>> + Send>>;
type Command = Arc<dyn Fn(Link, Value) -> Reply + Send + Sync>;

/// Errors reach the screens as one sentence, with its causes (`{:#}`).
pub fn say(err: impl std::fmt::Display) -> String {
    format!("{err:#}")
}

/// A document an undoable write changes: `doc(HABITS, &id)`.
pub fn doc(collection: &str, id: impl Into<String>) -> Which {
    Which {
        collection: collection.to_owned(),
        id: id.into(),
    }
}

/// The registry: every command by name. `C` is what each command is
/// handed: the link (the default), or a world's engine.
pub struct Commands<C = Link> {
    all: HashMap<String, Command>,
    /// The same writes, read first and kept for Undo (`undoable`).
    undoable: HashMap<String, Command>,
    of: Arc<dyn Fn(Link) -> C + Send + Sync>,
}

impl Default for Commands {
    fn default() -> Self {
        Self::over(|link| link)
    }
}

impl<C> Clone for Commands<C> {
    fn clone(&self) -> Self {
        Self {
            all: self.all.clone(),
            undoable: self.undoable.clone(),
            of: self.of.clone(),
        }
    }
}

impl<T: Send + Sync + 'static> Commands<Arc<T>> {
    /// Commands over a world's engine: each is handed `engine.get()`.
    pub fn engine(engine: &'static Shared<T>) -> Self {
        Self::over(move |_| engine.get())
    }
}

/// An engine's commands, as `World::commands` takes them.
impl<T: ?Sized> From<Commands<Arc<T>>> for Commands {
    fn from(c: Commands<Arc<T>>) -> Self {
        Self {
            all: c.all,
            undoable: c.undoable,
            of: Arc::new(|link| link),
        }
    }
}

/// Commands handed the link with a world's own state beside it, as
/// `World::commands` takes them.
impl<T: ?Sized> From<Commands<(Link, Arc<T>)>> for Commands {
    fn from(c: Commands<(Link, Arc<T>)>) -> Self {
        Self {
            all: c.all,
            undoable: c.undoable,
            of: Arc::new(|link| link),
        }
    }
}

impl<C: Send + 'static> Commands<C> {
    /// Commands handed what `of` makes of the link, when they run: the
    /// link with a world's own state beside it is `Commands::over(move
    /// |link| (link, titan.clone()))`.
    pub fn over(of: impl Fn(Link) -> C + Send + Sync + 'static) -> Self {
        Self {
            all: HashMap::new(),
            undoable: HashMap::new(),
            of: Arc::new(of),
        }
    }

    /// Registers `name`. The arguments arrive as the JSON object the screen
    /// passed (`()` for none); the reply is anything serialisable, and an
    /// error is said as one sentence.
    pub fn add<A, T, F, Fut>(&mut self, name: &str, f: F) -> &mut Self
    where
        A: DeserializeOwned + Send + 'static,
        T: Serialize,
        F: Fn(C, A) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = anyhow::Result<T>> + Send + 'static,
    {
        let (f, of) = (Arc::new(f), self.of.clone());
        self.put(
            name,
            Arc::new(move |link, args| {
                let (f, of) = (f.clone(), of.clone());
                Box::pin(async move {
                    let args = parse::<A>(args)?;
                    text(&f(of(link), args).await.map_err(say)?)
                })
            }),
        )
    }

    /// Registers `name` as a write the person can take back: `touches`
    /// says which documents it changes, read before it runs. Called as
    /// itself it is a command like any other; through the kit's
    /// `undoable` (`Sol.undoable(name, args, …)`) it answers `{ result,
    /// undo }`, and `restore { undo }` puts those documents back.
    pub fn undoable<A, T, W, WFut, F, Fut>(&mut self, name: &str, touches: W, f: F) -> &mut Self
    where
        A: DeserializeOwned + Clone + Send + 'static,
        T: Serialize,
        W: Fn(C, A) -> WFut + Send + Sync + 'static,
        WFut: Future<Output = anyhow::Result<Vec<Which>>> + Send + 'static,
        F: Fn(C, A) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = anyhow::Result<T>> + Send + 'static,
    {
        let (f, touches, of) = (Arc::new(f), Arc::new(touches), self.of.clone());
        let g = f.clone();
        self.add(name, move |c, a| g(c, a));
        self.undoable.insert(
            name.to_owned(),
            Arc::new(move |link, args| {
                let (f, touches, of) = (f.clone(), touches.clone(), of.clone());
                Box::pin(async move {
                    let args = parse::<A>(args)?;
                    let docs = touches(of(link.clone()), args.clone()).await.map_err(say)?;
                    let before = undo::snapshot(&link, &docs).await.map_err(say)?;
                    let out = text(&f(of(link), args).await.map_err(say)?)?;
                    Ok(kept(&out, before))
                })
            }),
        );
        self
    }

    /// Registers `name` as a write that makes documents (a new habit),
    /// which Undo deletes again: `made` names them from the reply.
    pub fn creates<A, T, M, F, Fut>(&mut self, name: &str, made: M, f: F) -> &mut Self
    where
        A: DeserializeOwned + Send + 'static,
        T: Serialize,
        M: Fn(&T) -> Vec<Which> + Send + Sync + 'static,
        F: Fn(C, A) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = anyhow::Result<T>> + Send + 'static,
    {
        let (f, made, of) = (Arc::new(f), Arc::new(made), self.of.clone());
        let g = f.clone();
        self.add(name, move |c, a| g(c, a));
        self.undoable.insert(
            name.to_owned(),
            Arc::new(move |link, args| {
                let (f, made, of) = (f.clone(), made.clone(), of.clone());
                Box::pin(async move {
                    let args = parse::<A>(args)?;
                    let out = f(of(link), args).await.map_err(say)?;
                    let before = made(&out)
                        .into_iter()
                        .map(|d| Before {
                            collection: d.collection,
                            id: d.id,
                            data: Value::Null,
                        })
                        .collect();
                    Ok(kept(&text(&out)?, before))
                })
            }),
        );
        self
    }

    /// Registers `name` as a command handed the link whatever `C` is, its
    /// error a sentence already (the desktop's `do` and `find`).
    pub(crate) fn add_linked<A, T, F, Fut>(&mut self, name: &str, f: F) -> &mut Self
    where
        A: DeserializeOwned + Send + 'static,
        T: Serialize,
        F: Fn(Link, A) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = Result<T, String>> + Send + 'static,
    {
        let f = Arc::new(f);
        self.put(
            name,
            Arc::new(move |link, args| {
                let f = f.clone();
                Box::pin(async move { text(&f(link, parse::<A>(args)?).await?) })
            }),
        )
    }

    /// Registers `name` with a reply that is JSON text already (the
    /// desktop's `status` and `ask`, whose answers have many types).
    pub(crate) fn add_text<F>(&mut self, name: &str, f: F) -> &mut Self
    where
        F: Fn(Link, Value) -> Reply + Send + Sync + 'static,
    {
        self.put(name, Arc::new(f))
    }

    fn put(&mut self, name: &str, command: Command) -> &mut Self {
        let before = self.all.insert(name.to_owned(), command);
        // Two commands by one name: the later (the kit's shared ones come
        // after the world's) would silently replace the world's own.
        debug_assert!(before.is_none(), "the command {name:?} is added twice");
        self
    }

    /// Whether there is a command called `name`.
    pub fn has(&self, name: &str) -> bool {
        self.all.contains_key(name)
    }

    /// Every command's name, sorted (a world's test keeps the list).
    pub fn names(&self) -> Vec<&str> {
        let mut names: Vec<&str> = self.all.keys().map(String::as_str).collect();
        names.sort_unstable();
        names
    }

    /// The names of the writes that can be taken back, sorted.
    pub fn undoable_names(&self) -> Vec<&str> {
        let mut names: Vec<&str> = self.undoable.keys().map(String::as_str).collect();
        names.sort_unstable();
        names
    }

    /// Runs `name` with `args`; an unknown name is a reply like any other.
    /// `undoable { command, args }` runs a write with its documents kept
    /// for Undo (a command that keeps none answers `undo: null`).
    pub fn call(&self, link: Link, name: &str, args: Value) -> Reply {
        if name == "undoable" {
            return self.call_undoable(link, args);
        }
        match self.all.get(name) {
            Some(command) => command(link, args),
            None => {
                let name = name.to_owned();
                Box::pin(async move { Err(format!("the app has no command {name:?}")) })
            }
        }
    }

    fn call_undoable(&self, link: Link, args: Value) -> Reply {
        #[derive(serde::Deserialize)]
        struct Write {
            command: String,
            #[serde(default)]
            args: Value,
        }
        let write: Write = match serde_json::from_value(args) {
            Ok(w) => w,
            Err(e) => return Box::pin(async move { Err(format!("bad arguments: {e}")) }),
        };
        if let Some(command) = self.undoable.get(&write.command) {
            return command(link, write.args);
        }
        let plain = self.call(link, &write.command, write.args);
        Box::pin(async move { Ok(format!(r#"{{"result":{},"undo":null}}"#, plain.await?)) })
    }
}

/// The reply with the token Undo sends back.
fn kept(result: &str, before: Vec<Before>) -> String {
    let token = undo::keep(before);
    format!(r#"{{"result":{result},"undo":{token}}}"#)
}

/// Straight to text: through a `Value`, an `f32` widens to `f64` and a
/// rating of 7.3 arrives as 7.300000190734863.
fn text(out: &impl Serialize) -> Result<String, String> {
    serde_json::to_string(out).map_err(say)
}

/// The arguments as the command's type. A command that takes none accepts
/// an empty object or nothing at all.
fn parse<A: DeserializeOwned>(args: Value) -> Result<A, String> {
    let empty = matches!(&args, Value::Object(m) if m.is_empty()) || args.is_null();
    match serde_json::from_value::<A>(args) {
        Ok(a) => Ok(a),
        Err(_) if empty => serde_json::from_value::<A>(Value::Null).map_err(|e| e.to_string()),
        Err(e) => Err(format!("bad arguments: {e}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(serde::Deserialize, Clone)]
    struct Add {
        a: i32,
        b: i32,
    }

    #[tokio::test]
    async fn runs_commands_by_name() {
        let (link, _dir) = orbit::testing::offline("test").await;
        let mut commands = Commands::default();
        commands
            .add("add", |_, a: Add| async move { Ok(a.a + a.b) })
            .add(
                "world",
                |link, ()| async move { Ok(link.world().to_owned()) },
            )
            .add("fails", |_, ()| async move {
                Err::<(), _>(anyhow::anyhow!("no").context("not done"))
            });
        let sum = commands
            .call(link.clone(), "add", serde_json::json!({ "a": 2, "b": 3 }))
            .await;
        assert_eq!(sum.as_deref(), Ok("5"));
        let world = commands.call(link.clone(), "world", Value::Null).await;
        assert_eq!(world.as_deref(), Ok("\"test\""));
        let world = commands
            .call(link.clone(), "world", serde_json::json!({}))
            .await;
        assert_eq!(world.as_deref(), Ok("\"test\""));
        assert!(
            commands
                .call(link.clone(), "nope", Value::Null)
                .await
                .is_err()
        );
        // The error is one sentence with its causes.
        let failed = commands.call(link.clone(), "fails", Value::Null).await;
        assert_eq!(failed, Err("not done: no".to_owned()));
        // A 32-bit float reaches the screens as written, not widened.
        commands.add("rating", |_, ()| async move { Ok(7.3f32) });
        let rating = commands.call(link, "rating", Value::Null).await;
        assert_eq!(rating.as_deref(), Ok("7.3"));
        assert_eq!(commands.names(), ["add", "fails", "rating", "world"]);
    }

    #[tokio::test]
    async fn an_engine_is_handed_to_each_command() {
        static ENGINE: Shared<i32> = Shared::new();
        ENGINE.set(Arc::new(40));
        let (link, _dir) = orbit::testing::offline("test").await;
        let mut commands = Commands::engine(&ENGINE);
        commands.add("answer", |n, a: Add| async move { Ok(*n + a.a + a.b) });
        let commands: Commands = commands.into();
        let answer = commands
            .call(link, "answer", serde_json::json!({ "a": 1, "b": 1 }))
            .await;
        assert_eq!(answer.as_deref(), Ok("42"));
    }

    #[derive(serde::Deserialize, Clone)]
    struct Id {
        id: String,
    }

    #[tokio::test]
    async fn a_write_is_taken_back_with_its_token() {
        let (link, _dir) = orbit::testing::offline("test").await;
        link.put("habits", "walk", serde_json::json!({ "name": "Walk" }))
            .await
            .unwrap();
        let mut commands = Commands::default();
        commands
            .undoable(
                "rename",
                |_, a: Id| async move { Ok(vec![doc("habits", a.id)]) },
                |link, a: Id| async move {
                    link.put("habits", &a.id, serde_json::json!({ "name": "Walk far" }))
                        .await?;
                    Ok(7.3f32)
                },
            )
            .creates(
                "create",
                |made: &String| vec![doc("habits", made.clone())],
                |link, ()| async move {
                    link.put("habits", "read", serde_json::json!({ "name": "Read" }))
                        .await?;
                    Ok("read".to_owned())
                },
            );
        assert_eq!(commands.undoable_names(), ["create", "rename"]);
        // Called plainly, a write answers as itself.
        let plain = commands
            .call(link.clone(), "rename", serde_json::json!({ "id": "walk" }))
            .await;
        assert_eq!(plain.as_deref(), Ok("7.3"));
        link.put("habits", "walk", serde_json::json!({ "name": "Walk" }))
            .await
            .unwrap();
        // Through `undoable`: the result and a token, which puts it back.
        let reply = commands
            .call(
                link.clone(),
                "undoable",
                serde_json::json!({ "command": "rename", "args": { "id": "walk" } }),
            )
            .await
            .unwrap();
        assert!(reply.starts_with(r#"{"result":7.3,"undo":"#), "{reply}");
        let reply: Value = serde_json::from_str(&reply).unwrap();
        let token = reply["undo"].as_u64().unwrap();
        let before = undo::take(token).unwrap();
        undo::restore(&link, &before, &["habits".to_owned()])
            .await
            .unwrap();
        let walk = link.get("habits", "walk").await.unwrap().unwrap();
        assert_eq!(walk.data["name"], "Walk");
        assert!(undo::take(token).is_none(), "a token is used once");
        // A creation is taken back by deleting what it made.
        let reply = commands
            .call(
                link.clone(),
                "undoable",
                serde_json::json!({ "command": "create" }),
            )
            .await
            .unwrap();
        let reply: Value = serde_json::from_str(&reply).unwrap();
        assert_eq!(reply["result"], "read");
        let before = undo::take(reply["undo"].as_u64().unwrap()).unwrap();
        undo::restore(&link, &before, &["habits".to_owned()])
            .await
            .unwrap();
        assert!(link.get("habits", "read").await.unwrap().is_none());
        // A command with no documents to keep answers without a token.
        commands.add("plain", |_, ()| async move { Ok(1) });
        let reply = commands
            .call(link, "undoable", serde_json::json!({ "command": "plain" }))
            .await;
        assert_eq!(reply.as_deref(), Ok(r#"{"result":1,"undo":null}"#));
    }

    #[test]
    #[cfg(debug_assertions)]
    #[should_panic(expected = "added twice")]
    fn a_command_is_not_silently_replaced() {
        let mut commands = Commands::default();
        commands
            .add("status", |_, ()| async move { Ok(1) })
            .add("status", |_, ()| async move { Ok(2) });
    }
}
