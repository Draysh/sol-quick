//! What a running world's app shares: the `World` a world hands the kit,
//! the `Runtime` (the link, the commands, the update checker) and the
//! world's own calls to it (`emit`, `open`, `quit`, the data and cache
//! folders). Starting the app and its window (`sol_quick::run`) is in the
//! sol-quick crate, the one half that needs Qt.

use std::{
    path::PathBuf,
    sync::{
        Arc, Mutex, OnceLock,
        atomic::{AtomicBool, Ordering},
    },
};

use orbit::{
    install::{self, App},
    link::{Handler, Link},
    moons,
    updates::{self, Updates},
};

use crate::{commands::Commands, single};

/// What a world hands the kit to run as an app.
pub struct World {
    /// `sol-world.json`.
    pub manifest: &'static str,
    /// The key release files are signed with (`scripts/signing-key.sh`
    /// writes it). Empty: the app never installs an update.
    pub update_key: &'static str,
    /// `env!("CARGO_PKG_VERSION")`.
    pub version: &'static str,
    /// `env!("CARGO_PKG_NAME")`: the binary, and the window class.
    pub bin: &'static str,
    /// The app icon at a few sizes, PNG.
    pub icons: &'static [(u32, &'static [u8])],
    /// What Sol calls into.
    pub handler: Arc<dyn Handler>,
    /// The world's own commands (the shared ones are added here).
    pub commands: Commands,
    /// The QML to load: `qrc:/qt/qml/Sol/Terra/qml/Main.qml`.
    pub main: &'static str,
    /// `env!("CARGO_MANIFEST_DIR")`: the world's checkout. A preview with
    /// `SOL_QML_LIVE=1` reads the screens from its `qml/` (and the kit's
    /// from the kit's), so an edit shows without a build.
    pub source: &'static str,
    /// With `SOL_PREVIEW`, fills the throwaway copy with sample data the
    /// first time, so the screens have something to show. Runs after
    /// `prepare`, so what that set up is there to fill.
    pub sample: Option<Sample>,
    /// Runs once the link is open and before sync starts: for state a world
    /// builds around the link (a player, a library engine).
    pub prepare: Option<Prepare>,
    /// The world's own entries in the tray's menu, before Open and Quit:
    /// `(id, label)`; a choice reaches the screens as a `tray` event.
    pub tray: &'static [crate::desktop::TrayItem],
    /// Keys that work from any app, bound through the desktop's portal:
    /// `(id, what it does, preferred keys)`; a press is a `shortcut` event.
    pub shortcuts: &'static [crate::desktop::Shortcut],
}

pub type Prepare = Box<dyn FnOnce(&Link, &tokio::runtime::Handle) + Send>;

pub type Sample = Arc<
    dyn Fn(Link) -> std::pin::Pin<Box<dyn std::future::Future<Output = anyhow::Result<()>> + Send>>
        + Send
        + Sync,
>;

/// What Rust tells the window, from any thread; `SolBackend` passes each
/// on to the Qt thread.
#[doc(hidden)]
pub enum ToWindow {
    /// Come up: another copy knocked, or the tray was clicked.
    Activate,
    /// A moon's planet has closed.
    PlanetGone,
    /// Quit the way the window would: it closes, then the app leaves.
    Quit,
    /// Whether the tray is there to come back from, so closing may hide.
    Tray(bool),
    /// A world's own event: a name and its JSON.
    Event(String, String),
    /// Open a page: `/title?key=x` (another app asked, or `--open`).
    Open(String),
    /// Open quick capture over the desktop (its key was pressed).
    Capture,
}

#[doc(hidden)]
pub type ToWindowFn = Box<dyn Fn(ToWindow) + Send + Sync>;

/// Everything the running app shares between Rust and the screens.
pub struct Runtime {
    pub link: Link,
    pub updates: Arc<Updates>,
    pub commands: Commands,
    pub tokio: tokio::runtime::Handle,
    pub manifest_json: String,
    /// The world's name alone ("Terra"); `app.name` carries its role too.
    pub name: String,
    /// What the app is for ("Habits and diary"), from sol-world.json.
    pub role: String,
    pub app: App,
    /// Started without a window: by its planet (a moon), or at login.
    pub background: bool,
    /// Why the local copy didn't open (`{ problem, path, detail }`, JSON),
    /// when it didn't: the app then runs on an empty stand-in copy and the
    /// window asks the person what to do.
    pub problem: Option<String>,
    /// `SOL_PREVIEW`: a throwaway local copy and the Shell without pairing, for working on screens.
    pub preview: bool,
    /// The app sits in the tray: closing the window hides it, Quit is in
    /// the tray's menu. False until the tray is up, and again if it goes.
    pub tray: AtomicBool,
    pub data_dir: PathBuf,
    #[doc(hidden)]
    pub window: Mutex<Option<ToWindowFn>>,
    #[doc(hidden)]
    pub told: Mutex<Option<String>>,
    /// A planet's hold on its "running" lock, for as long as it runs.
    #[doc(hidden)]
    pub _moons: Option<moons::Running>,
}

#[doc(hidden)]
pub static RUNTIME: OnceLock<Runtime> = OnceLock::new();

pub fn runtime() -> &'static Runtime {
    RUNTIME.get().expect("sol_quick::run started the app")
}

impl Runtime {
    /// Where messages for the window go, once it is up.
    #[doc(hidden)]
    pub fn set_window(&self, f: impl Fn(ToWindow) + Send + Sync + 'static) {
        *self.window.lock().expect("window lock") = Some(Box::new(f));
    }

    /// Tells the window; false while there is none yet.
    #[doc(hidden)]
    pub fn tell(&self, message: ToWindow) -> bool {
        match self.window.lock().expect("window lock").as_ref() {
            Some(f) => {
                f(message);
                true
            }
            None => false,
        }
    }

    /// Brings the window up, from the tray or another copy knocking.
    pub fn activate_window(&self) {
        self.tell(ToWindow::Activate);
    }

    /// The tray came (or went): closing the window hides it only while it is there.
    #[doc(hidden)]
    pub fn set_tray(&self, up: bool) {
        self.tray.store(up, Ordering::Relaxed);
        self.tell(ToWindow::Tray(up));
    }

    fn window_file() -> PathBuf {
        runtime().data_dir.join("window.json")
    }

    #[doc(hidden)]
    pub fn read_window() -> Option<String> {
        std::fs::read_to_string(Self::window_file()).ok()
    }

    #[doc(hidden)]
    pub fn write_window(state: &str) {
        let _ = std::fs::write(Self::window_file(), state);
    }
}

/// A page asked for before the window could take it (`--open`, or a knock
/// while starting); the window opens it once it is up.
static PENDING_OPEN: Mutex<Option<String>> = Mutex::new(None);

/// Opens `path` in the window and brings it up, or keeps it for the window.
#[doc(hidden)]
pub fn open_page(path: String) {
    match RUNTIME.get() {
        Some(rt) if rt.tell(ToWindow::Open(path.clone())) => rt.activate_window(),
        _ => *PENDING_OPEN.lock().expect("pending lock") = Some(path),
    }
}

/// Opens `path` (`/review`) in this app's window and brings it up: for
/// something the desktop asked of it (quick capture's "review").
pub fn open(path: &str) {
    open_page(path.to_owned());
}

/// The page asked for before the window was up, once.
#[doc(hidden)]
pub fn take_pending_open() -> Option<String> {
    PENDING_OPEN.lock().expect("pending lock").take()
}

/// Once per version: a newer one is out, or one was put in place quietly.
#[doc(hidden)]
pub fn news(status: &updates::Status) -> Option<String> {
    let (key, news) = match &status.state {
        updates::State::Available { offer, .. } => (
            format!("available:{}", offer.version),
            format!("Version {} is out. Settings has it.", offer.version),
        ),
        updates::State::Ready { version } => (
            format!("ready:{version}"),
            format!("Version {version} is installed and runs from the next start."),
        ),
        _ => return None,
    };
    let mut told = runtime().told.lock().expect("told lock");
    if told.as_deref() == Some(&key) {
        return None;
    }
    *told = Some(key);
    Some(news)
}

/// How this device appears in Sol: the computer's name.
pub fn device_name() -> String {
    gethostname::gethostname()
        .into_string()
        .ok()
        .filter(|n| !n.is_empty())
        .unwrap_or_else(|| "Desktop".into())
}

/// The app's data folder for `world`: the local copy, the window's state,
/// anything the world keeps on this device. A throwaway one with
/// `SOL_PREVIEW`.
pub fn data_dir(world: &str) -> PathBuf {
    let dir = if std::env::var_os("SOL_PREVIEW").is_some() {
        std::env::temp_dir().join(format!("sol-preview-{world}"))
    } else {
        dirs::data_dir()
            .unwrap_or_else(std::env::temp_dir)
            .join(format!("digital.sachi.sol.{world}"))
    };
    let _ = std::fs::create_dir_all(&dir);
    dir
}

/// Where `world` keeps what it can fetch again (pictures, covers, spoken
/// words): `~/.cache/digital.sachi.sol.<world>`. With `SOL_PREVIEW`, the
/// throwaway copy's own folder (`data_dir`), so a preview's files never mix
/// with the real ones. Not made here: whoever writes into it makes it.
pub fn cache_dir(world: &str) -> PathBuf {
    if std::env::var_os("SOL_PREVIEW").is_some() {
        data_dir(world)
    } else {
        dirs::cache_dir()
            .unwrap_or_else(std::env::temp_dir)
            .join(format!("digital.sachi.sol.{world}"))
    }
}

/// Tells the screens something of the world's own: `Sol.event(name, data)`
/// in QML. Dropped while no window listens yet.
pub fn emit(name: &str, data: &impl serde::Serialize) {
    if let Some(rt) = RUNTIME.get()
        && let Ok(json) = serde_json::to_string(data)
    {
        rt.tell(ToWindow::Event(name.to_owned(), json));
    }
}

/// Quits the app from anywhere: the window closes on Qt's thread, then
/// `run` leaves. Without a window yet, it leaves at once.
pub fn quit() {
    if !RUNTIME.get().is_some_and(|rt| rt.tell(ToWindow::Quit)) {
        leave(0);
    }
}

/// Exits now, closing the single-instance door behind it. From the Qt
/// thread after the window has gone, or before there is one; elsewhere,
/// `quit`.
pub fn leave(code: i32) -> ! {
    if code == 0 && TRYING.load(Ordering::Relaxed) {
        // A version just put in place ran and left cleanly: it stays.
        if let Some(rt) = RUNTIME.get() {
            install::started_well(&rt.app);
        }
    }
    single::leave();
    crate::status::leave();
    // The empty copy a window that couldn't open its own ran on goes with it.
    if let Some(stand_in) = STAND_IN.lock().ok().and_then(|mut s| s.take()) {
        let _ = std::fs::remove_dir_all(stand_in);
    }
    std::process::exit(code)
}

/// The empty local copy in the temporary folder that stands in for one that
/// didn't open, removed when the app leaves.
#[doc(hidden)]
pub static STAND_IN: Mutex<Option<std::path::PathBuf>> = Mutex::new(None);

/// This version was just put in place by an update, and hasn't yet been
/// seen to come up.
#[doc(hidden)]
pub static TRYING: AtomicBool = AtomicBool::new(false);
