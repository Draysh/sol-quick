//! Starting a world's app: the command line, one copy at a time, the
//! connection to Sol (`orbit::link::Link`), installing and updating
//! itself, moons that run with their planet, and at last the window.
//!
//! `start.rs` is the start-up itself, phase by phase; what the running app
//! shares (`World`, `Runtime`, `emit`, `quit`, the folders) is
//! `sol_quick_core::app`, all of it here too.

mod start;

pub use sol_quick_core::app::*;
pub use start::run;

/// The Qt this binary was built with (`build.rs`).
pub(crate) const BUILT_QT: &str = env!("SOL_QT_VERSION");
