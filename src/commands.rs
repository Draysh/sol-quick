//! The commands a world's screens call. Each is an async function from
//! JSON arguments to a JSON reply (or one sentence on why not), named as
//! the screens name it: `Sol.call("tick_habit", { id, done: true })`.
//!
//! ```ignore
//! commands.add("list_habits", |link, _: ()| async move { habits::habits(&link).await.map_err(say) });
//! commands.add("tick_habit", |link, a: Tick| async move { habits::set_done(&link, &a.id, a.done).await.map_err(say) });
//! ```

use std::{collections::HashMap, future::Future, pin::Pin, sync::Arc};

use orbit::link::Link;
use serde::{Serialize, de::DeserializeOwned};
use serde_json::Value;

/// What a command answers: its reply as JSON text, or one sentence on why not.
pub type Reply = Pin<Box<dyn Future<Output = Result<String, String>> + Send>>;
type Command = Arc<dyn Fn(Link, Value) -> Reply + Send + Sync>;

/// Errors reach the screens as one sentence, with its causes (`{:#}`).
pub fn say(err: impl std::fmt::Display) -> String {
    format!("{err:#}")
}

/// The registry: every command by name.
#[derive(Default, Clone)]
pub struct Commands(HashMap<String, Command>);

impl Commands {
    /// Registers `name`. The arguments arrive as the JSON object the screen
    /// passed (`()` for none); the reply is anything serialisable.
    pub fn add<A, T, F, Fut>(&mut self, name: &str, f: F) -> &mut Self
    where
        A: DeserializeOwned + Send + 'static,
        T: Serialize,
        F: Fn(Link, A) -> Fut + Send + Sync + 'static,
        Fut: Future<Output = Result<T, String>> + Send + 'static,
    {
        let f = Arc::new(f);
        self.0.insert(
            name.to_owned(),
            Arc::new(move |link, args| {
                let f = f.clone();
                Box::pin(async move {
                    let args = parse::<A>(args)?;
                    let out = f(link, args).await?;
                    // Straight to text: through a `Value`, an `f32` widens to
                    // `f64` and a rating of 7.3 arrives as 7.300000190734863.
                    serde_json::to_string(&out).map_err(say)
                })
            }),
        );
        self
    }

    /// Runs `name` with `args`; an unknown name is a reply like any other.
    pub fn call(&self, link: Link, name: &str, args: Value) -> Reply {
        match self.0.get(name) {
            Some(command) => command(link, args),
            None => {
                let name = name.to_owned();
                Box::pin(async move { Err(format!("the app has no command {name:?}")) })
            }
        }
    }
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

    #[derive(serde::Deserialize)]
    struct Add {
        a: i32,
        b: i32,
    }

    #[tokio::test]
    async fn runs_commands_by_name() {
        let dir = tempfile::tempdir().unwrap();
        let link = Link::open(orbit::link::Config {
            world: "test".into(),
            dir: dir.path().to_owned(),
            device: "Test".into(),
            platform: None,
            version: "0.1.0".into(),
            tokens: orbit::link::Tokens::File,
        })
        .await
        .unwrap();
        let mut commands = Commands::default();
        commands
            .add("add", |_, a: Add| async move { Ok(a.a + a.b) })
            .add(
                "world",
                |link, _: ()| async move { Ok(link.world().to_owned()) },
            );
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
        // A 32-bit float reaches the screens as written, not widened.
        commands.add("rating", |_, _: ()| async move { Ok(7.3f32) });
        let rating = commands.call(link, "rating", Value::Null).await;
        assert_eq!(rating.as_deref(), Ok("7.3"));
    }
}
