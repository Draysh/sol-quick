//! A world's engine: the state it builds once the link is open (`prepare`)
//! and its commands and handler share, for a world that needs one (a
//! library, a player, a dictionary).
//!
//! ```ignore
//! static ENGINE: sol_quick::Shared<Engine> = sol_quick::Shared::new();
//!
//! commands.add("today", |_, _: ()| async move { world::today(&ENGINE.get()).await });
//! sol_quick::run(World {
//!     // Sol's deliveries reach `world::World` around the engine, once it is built.
//!     handler: sol_quick::handler(|| world::World(ENGINE.get())),
//!     prepare: Some(Box::new(|link, tokio| { ENGINE.set(Engine::new(link.clone())); })),
//!     ..
//! })
//! ```

use std::sync::{Arc, OnceLock};

use orbit::{
    device::Delivery,
    link::{Boxed, Handler, Link},
};

/// Something built once (in `prepare`) and shared from then on: a `static`
/// the commands and the handler read.
pub struct Shared<T>(OnceLock<Arc<T>>);

impl<T> Shared<T> {
    pub const fn new() -> Self {
        Self(OnceLock::new())
    }

    /// Keeps `value`, the first time; later calls change nothing.
    pub fn set(&self, value: Arc<T>) {
        let _ = self.0.set(value);
    }

    /// What was kept. Commands and deliveries only come once `prepare` has
    /// run, so before `set` this is a bug, and it panics.
    pub fn get(&self) -> Arc<T> {
        self.0.get().expect("the engine is prepared").clone()
    }

    /// What was kept, if it is there yet.
    pub fn try_get(&self) -> Option<Arc<T>> {
        self.0.get().cloned()
    }
}

impl<T> Default for Shared<T> {
    fn default() -> Self {
        Self::new()
    }
}

/// What Sol calls into, made afresh for each delivery by `make`: for a
/// world whose handler wraps state that only exists after `prepare`
/// (`|| world::World(ENGINE.get())`). Both of the handler's calls go to
/// what `make` returns.
pub fn handler<H: Handler>(make: fn() -> H) -> Arc<dyn Handler> {
    Arc::new(MadeEachTime(make))
}

struct MadeEachTime<H>(fn() -> H);

impl<H: Handler> Handler for MadeEachTime<H> {
    fn deliver<'a>(&'a self, link: &'a Link, d: &'a Delivery) -> Boxed<'a, anyhow::Result<()>> {
        let make = self.0;
        Box::pin(async move { make().deliver(link, d).await })
    }

    fn changed<'a>(&'a self, link: &'a Link, collections: &'a [String]) -> Boxed<'a, ()> {
        let make = self.0;
        Box::pin(async move { make().changed(link, collections).await })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shared_keeps_the_first() {
        static KEPT: Shared<u32> = Shared::new();
        assert!(KEPT.try_get().is_none());
        KEPT.set(Arc::new(1));
        KEPT.set(Arc::new(2));
        assert_eq!(*KEPT.get(), 1);
    }
}
