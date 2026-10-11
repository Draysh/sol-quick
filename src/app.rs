//! Starting a world's app: the command line, one copy at a time, the
//! connection to Sol (`orbit::link::Link`), installing and updating
//! itself, moons that run with their planet, and at last the window.

use std::{
    path::PathBuf,
    sync::{
        Arc, Mutex, OnceLock,
        atomic::{AtomicBool, Ordering},
    },
};

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QString, QUrl};
use orbit::{
    WorldManifest,
    install::{self, App},
    link::{Config, Handler, Link, LocalCopyError, Status, Tokens},
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
pub(crate) enum ToWindow {
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

type ToWindowFn = Box<dyn Fn(ToWindow) + Send + Sync>;

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
    window: Mutex<Option<ToWindowFn>>,
    told: Mutex<Option<String>>,
    /// A planet's hold on its "running" lock, for as long as it runs.
    _moons: Option<moons::Running>,
}

static RUNTIME: OnceLock<Runtime> = OnceLock::new();

pub fn runtime() -> &'static Runtime {
    RUNTIME.get().expect("sol_quick::run started the app")
}

impl Runtime {
    /// Where messages for the window go, once it is up.
    pub(crate) fn set_window(&self, f: impl Fn(ToWindow) + Send + Sync + 'static) {
        *self.window.lock().expect("window lock") = Some(Box::new(f));
    }

    /// Tells the window; false while there is none yet.
    pub(crate) fn tell(&self, message: ToWindow) -> bool {
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
    pub(crate) fn set_tray(&self, up: bool) {
        self.tray.store(up, Ordering::Relaxed);
        self.tell(ToWindow::Tray(up));
    }

    fn window_file() -> PathBuf {
        runtime().data_dir.join("window.json")
    }

    pub(crate) fn read_window() -> Option<String> {
        std::fs::read_to_string(Self::window_file()).ok()
    }

    pub(crate) fn write_window(state: &str) {
        let _ = std::fs::write(Self::window_file(), state);
    }
}

/// A page asked for before the window could take it (`--open`, or a knock
/// while starting); the window opens it once it is up.
static PENDING_OPEN: Mutex<Option<String>> = Mutex::new(None);

/// Opens `path` in the window and brings it up, or keeps it for the window.
fn open_page(path: String) {
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
pub(crate) fn take_pending_open() -> Option<String> {
    PENDING_OPEN.lock().expect("pending lock").take()
}

/// Once per version: a newer one is out, or one was put in place quietly.
pub(crate) fn news(status: &updates::Status) -> Option<String> {
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

fn platform() -> Option<String> {
    cfg!(target_os = "linux").then(|| "linux".into())
}

/// The Qt this binary was built with (`build.rs`).
pub(crate) const BUILT_QT: &str = env!("SOL_QT_VERSION");

/// The Qt this process runs on: the version of the Qt Core library loaded
/// (`libQt6Core.so.6.10.1`), else the one it was built with.
fn running_qt() -> &'static str {
    let loaded = std::fs::read_to_string("/proc/self/maps")
        .ok()
        .and_then(|maps| {
            maps.lines().find_map(|line| {
                let file = line.rsplit('/').next()?;
                let version = file.strip_prefix("libQt6Core.so.")?;
                (version.matches('.').count() >= 2).then(|| version.trim().to_owned())
            })
        });
    match loaded {
        Some(v) => Box::leak(v.into_boxed_str()),
        None => BUILT_QT,
    }
}

/// Where the app's log goes: its own state folder
/// (`~/.local/state/digital.sachi.sol.<world>/<world>.log`), or the
/// preview's throwaway folder.
fn log_file(world: &str, preview: bool) -> PathBuf {
    let dir = if preview {
        data_dir(world)
    } else {
        dirs::state_dir()
            .or_else(dirs::data_dir)
            .unwrap_or_else(std::env::temp_dir)
            .join(format!("digital.sachi.sol.{world}"))
    };
    dir.join(format!("{world}.log"))
}

/// What the app is for, in a word or three: `role` in sol-world.json
/// ("Habits and diary"). Sol doesn't read it; the app menu and the tray do.
fn role(manifest: &WorldManifest) -> Option<String> {
    manifest
        .role
        .as_deref()
        .map(str::trim)
        .filter(|r| !r.is_empty())
        .map(str::to_owned)
}

fn make_app(world: &World, manifest: &WorldManifest) -> App {
    let leak = |s: &str| -> &'static str { Box::leak(s.to_owned().into_boxed_str()) };
    // In the app menu with what it is for, so a planet's name needn't be remembered.
    let name = match role(manifest) {
        Some(role) => format!("{} · {role}", manifest.name),
        None => manifest.name.clone(),
    };
    App {
        world: leak(&manifest.id),
        name: leak(&name),
        comment: leak(&manifest.tagline),
        version: world.version,
        wm_class: world.bin,
        icons: world.icons,
        // One key per line; any of them signs an update.
        pubkey: Some(world.update_key.trim()).filter(|k| !k.is_empty()),
        qt: None,
    }
}

/// `--install`, `--uninstall` and `--version` from a terminal, and the
/// desktop's `--status`, `--do` and `--find`, before any window opens.
fn command_line(app: &App, name: &str, parent: Option<&str>) -> Option<i32> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let arg = args.first()?.clone();
    let preview = std::env::var_os("SOL_PREVIEW").is_some();
    match arg.as_str() {
        "--status" => return Some(crate::status::print(app.world, name, preview)),
        "--do" => return Some(crate::door::act(app.world, name, preview, &args[1..])),
        "--find" => return Some(crate::door::find(app.world, name, preview, &args[1..])),
        _ => {}
    }
    let done = match arg.as_str() {
        "--install" => install::install(app).map(|bin| {
            // The other apps on this computer can open this one from now on.
            orbit::doors::settle_installed(app, &bin);
            if let Some(parent) = parent {
                moons::settle_installed(app, parent, &bin);
            }
            format!("Installed {}: {}", app.name, bin.display())
        }),
        "--uninstall" => install::uninstall(app).map(|()| {
            format!(
                "Removed {}. Its data stays in Sol; the local copy stays in the app's data folder.",
                app.name
            )
        }),
        // Also how an update is tried before it goes in: the Qt is checked.
        "--version" => Ok(format!("{name} {} (Qt {BUILT_QT})", app.version)),
        _ => return None,
    };
    Some(match done {
        Ok(said) => {
            println!("{said}");
            0
        }
        Err(err) => {
            eprintln!("{err:#}");
            1
        }
    })
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
static STAND_IN: Mutex<Option<std::path::PathBuf>> = Mutex::new(None);

/// This version was just put in place by an update, and hasn't yet been
/// seen to come up.
static TRYING: AtomicBool = AtomicBool::new(false);

/// After an update that didn't come up was rolled back: the local copy goes
/// back to how it was before that version migrated it (the copy it made in
/// `backups/` first), with the one it left set aside; then the version
/// before starts again and this one leaves.
fn after_roll_back(trial: &install::Trial, world: &str, data_dir: &std::path::Path) -> ! {
    let since: std::time::SystemTime = trial.at.into();
    let backup = std::fs::read_dir(data_dir.join("backups"))
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| {
            let made = e.metadata().ok()?.modified().ok()?;
            let name = e.file_name().into_string().ok()?;
            (made >= since && name.starts_with(&format!("{world}-schema")))
                .then_some((made, e.path()))
        })
        .min();
    if let Some((_, backup)) = backup {
        match orbit::link::set_aside(data_dir, world).and_then(|_| {
            Ok(std::fs::copy(
                &backup,
                data_dir.join(format!("{world}.db")),
            )?)
        }) {
            Ok(_) => {
                tracing::warn!(from = %backup.display(), "the local copy is back as it was before the update")
            }
            Err(err) => tracing::error!(error = ?err, "couldn't put the local copy back"),
        }
    }
    match install::current_exe()
        .map_err(anyhow::Error::from)
        .and_then(|bin| install::relaunch(&bin))
    {
        Ok(()) => {
            tracing::warn!(version = %trial.from, "starting the version before the update again")
        }
        Err(err) => tracing::error!(error = ?err, "couldn't start the version before the update"),
    }
    single::leave();
    std::process::exit(0)
}

/// SIGTERM and SIGINT (a shutdown, `kill`, Ctrl+C) quit the way the tray's
/// Quit does: the window keeps its state, the door closes, and the moons
/// hear the planet go. A second signal, or a window that doesn't close
/// within a few seconds, leaves at once.
fn quit_on_signals(tokio: &tokio::runtime::Handle) {
    use tokio::signal::unix::{SignalKind, signal};
    tokio.spawn(async {
        let (Ok(mut term), Ok(mut int)) = (
            signal(SignalKind::terminate()),
            signal(SignalKind::interrupt()),
        ) else {
            tracing::warn!("no signal handlers; a SIGTERM ends the app at once");
            return;
        };
        tokio::select! {
            _ = term.recv() => {}
            _ = int.recv() => {}
        }
        tracing::info!("asked to stop; quitting");
        quit();
        tokio::select! {
            _ = term.recv() => {}
            _ = int.recv() => {}
            () = tokio::time::sleep(std::time::Duration::from_secs(5)) => {}
        }
        leave(0)
    });
}

/// Runs the app. Never returns.
pub fn run(world: World) -> ! {
    let manifest: WorldManifest =
        serde_json::from_str(world.manifest).expect("sol-world.json is a world manifest");
    let mut app = make_app(&world, &manifest);
    let parent = manifest.parent.clone();
    // First, and before anything is written: `--version` is how an update
    // is tried before it goes in.
    if let Some(code) = command_line(&app, &manifest.name, parent.as_deref()) {
        std::process::exit(code);
    }
    app.qt = Some(running_qt());
    let preview = std::env::var_os("SOL_PREVIEW").is_some();
    orbit::telemetry::init_app(&log_file(&manifest.id, preview));
    let data_dir = data_dir(&manifest.id);
    // Started by its planet (a moon) or at login: no window, just the work.
    let by_planet = parent.is_some() && moons::in_background();
    let background = moons::in_background() || crate::autostart::at_login();
    // One copy at a time: a later one brings this one's window up and leaves.
    // `--open /title?key=x`: at that page (here, or in the copy already running).
    let open_at = std::env::args()
        .skip_while(|a| a != "--open")
        .nth(1)
        .filter(|p| p.starts_with('/'));
    let knock = if background {
        None
    } else {
        Some(
            open_at
                .clone()
                .map_or(single::Knock::Show, single::Knock::Open),
        )
    };
    let first = single::claim(&manifest.id, preview, knock, |knock| match knock {
        single::Knock::Show => {
            if let Some(rt) = RUNTIME.get() {
                rt.activate_window();
            }
            None
        }
        single::Knock::Open(path) => {
            open_page(path);
            None
        }
        // The desktop asks for something done or found, or another world
        // asks a question: only these three of the world's commands are
        // reachable this way.
        // Quick capture's key: this app opens the line over the desktop.
        single::Knock::Ask(command, _) if command == "capture" => Some(match RUNTIME.get() {
            Some(rt) if rt.tell(ToWindow::Capture) => Ok("\"open\"".into()),
            _ => Err("the app is still starting; try again in a moment".into()),
        }),
        single::Knock::Ask(command, args) => Some(match RUNTIME.get() {
            Some(rt) if matches!(command.as_str(), "do" | "find" | "ask") => rt
                .tokio
                .block_on(rt.commands.call(rt.link.clone(), &command, args)),
            Some(_) => Err(format!("nothing answers {command:?} from the desktop")),
            None => Err("the app is still starting; try again in a moment".into()),
        }),
    });
    if let Some(path) = open_at {
        open_page(path);
    }
    if !first {
        std::process::exit(0);
    }
    // A version just put in place by an update: this start counts, and one
    // that started before and never came up goes back to the one before.
    // (After the door: a second copy knocking isn't a start.)
    match install::on_start(&app) {
        install::Start::Normal => {}
        install::Start::Trying => TRYING.store(true, Ordering::Relaxed),
        install::Start::RolledBack(trial) => after_roll_back(&trial, &manifest.id, &data_dir),
    }

    let tokio = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .thread_name("sol-tokio")
        .build()
        .expect("a tokio runtime");
    // The main thread works inside the runtime from here on: the link spawns
    // its sync and inbox tasks when it starts paired (and Qt's thread later
    // spawns through `rt.tokio`).
    let _inside = tokio.enter();
    std::fs::create_dir_all(&data_dir).expect("the app's data folder");
    quit_on_signals(tokio.handle());

    let config = |dir: PathBuf, tokens| Config {
        world: manifest.id.clone(),
        dir,
        device: device_name(),
        platform: platform(),
        version: world.version.into(),
        tokens,
    };
    let tokens = if preview {
        Tokens::File
    } else {
        Tokens::Keyring
    };
    let (link, problem) = match tokio.block_on(Link::open(config(data_dir.clone(), tokens))) {
        Ok(link) => (link, None),
        // The local copy won't open (a newer version wrote it, or it's
        // damaged): the window asks what to do, on an empty stand-in.
        Err(err) => {
            tracing::error!(error = ?err, "the local copy didn't open");
            let (problem, path, detail) = match err.downcast_ref::<LocalCopyError>() {
                Some(e) => (
                    serde_json::to_value(e.problem).unwrap_or_default(),
                    e.path.display().to_string(),
                    e.detail.clone(),
                ),
                None => (
                    "other".into(),
                    data_dir.display().to_string(),
                    format!("{err:#}"),
                ),
            };
            let stand_in = std::env::temp_dir().join(format!(
                "sol-{}-stand-in-{}",
                manifest.id,
                std::process::id()
            ));
            if let Ok(mut kept) = STAND_IN.lock() {
                *kept = Some(stand_in.clone());
            }
            let link = tokio
                .block_on(Link::open(config(stand_in, Tokens::File)))
                .expect("an empty stand-in copy opens");
            let problem = serde_json::json!({ "problem": problem, "path": path, "detail": detail });
            (link, Some(problem.to_string()))
        }
    };

    // The app-menu entry follows the installed version; updates come through Sol.
    install::refresh(&app);
    crate::autostart::refresh(&app);
    // Other apps on this computer can open this one from their sidebars.
    orbit::doors::settle(&app);
    let running = match &parent {
        // Its planet starts it from where it says it is.
        Some(parent) => {
            moons::settle(&app, parent);
            None
        }
        // A preview runs alone: the installed moons stay as they are; and
        // a copy that didn't open does nothing until the person chose.
        None if preview || problem.is_some() => None,
        // A planet's moons run whenever it does.
        None => moons::start(app.world),
    };
    if let Some(prepare) = world.prepare {
        prepare(&link, tokio.handle());
    }
    if preview
        && problem.is_none()
        && let Some(sample) = &world.sample
        && !data_dir.join("sampled").exists()
    {
        match tokio.block_on(sample(link.clone())) {
            Ok(()) => {
                let _ = std::fs::write(data_dir.join("sampled"), "");
            }
            Err(why) => tracing::warn!("sample data: {why:#}"),
        }
    }
    let updates = tokio.block_on(Updates::new(link.clone(), app));
    tokio.spawn(updates.clone().watch());

    let mut commands = world.commands;
    crate::shared::add(
        &mut commands,
        app,
        parent.clone(),
        manifest.collections.clone(),
    );

    let rt = Runtime {
        link: link.clone(),
        updates,
        commands,
        tokio: tokio.handle().clone(),
        manifest_json: world.manifest.to_owned(),
        name: manifest.name.clone(),
        role: role(&manifest).unwrap_or_default(),
        app,
        background,
        problem,
        preview,
        tray: AtomicBool::new(false),
        data_dir,
        window: Mutex::new(None),
        told: Mutex::new(None),
        _moons: running,
    };
    if RUNTIME.set(rt).is_err() {
        panic!("sol_quick::run twice");
    }
    // What the desktop around the app shows of it (the bar, the terminal).
    crate::status::start(runtime());

    // A moon its planet started, without a window, leaves a few seconds
    // after its planet does (or at once, unpaired: there's nothing to do
    // until it's opened and paired).
    if let Some(parent) = parent.filter(|_| by_planet) {
        let unpaired = matches!(link.status(), Status::Unpaired { .. });
        if unpaired {
            leave(0);
        }
        tokio.spawn(async move {
            loop {
                moons::planet_gone(&parent).await;
                runtime().tell(ToWindow::PlanetGone);
            }
        });
    }

    // The Sol tray, for every app here but a preview (a moon its planet
    // started is there too, to be opened); global shortcuts beside a window.
    if !preview {
        crate::tray::start(world.tray);
    }
    // Shortcuts for every window there may be: a planet that started hidden
    // (with the computer) too, not a moon its planet started.
    if !preview && !by_planet {
        crate::desktop::start(world.shortcuts);
    }
    runtime().tokio.spawn_blocking(crate::seen::prune);
    // Sync; the screens follow through `SolBackend`.
    link.start(world.handler);

    // The window. Qt owns the main thread from here.
    let mut gui = QGuiApplication::new();
    // The .desktop file orbit::install writes: the desktop looks the icon and the name up under it.
    QGuiApplication::set_desktop_file_name(&QString::from(&format!("sol-{}", manifest.id)));
    if let Some(mut gui) = gui.as_mut() {
        gui.as_mut()
            .set_application_name(&QString::from(&manifest.name));
        gui.as_mut()
            .set_application_version(&QString::from(world.version));
        gui.as_mut()
            .set_organization_domain(&QString::from("sachi.digital"));
    }
    let mut engine = QQmlApplicationEngine::new();
    // A window that fails to load (a QML error, a Qt module missing) ends the
    // app, rather than leaving it running with nothing to show.
    let failed = Arc::new(AtomicBool::new(false));
    if let Some(mut engine) = engine.as_mut() {
        let flag = failed.clone();
        let _guard = engine
            .as_mut()
            .on_object_creation_failed(move |_, url| {
                tracing::error!("the window failed to load: {url}");
                flag.store(true, Ordering::Relaxed);
            })
            .release();
        if crate::live::asked(runtime().preview) {
            crate::live::read_from_disk(
                engine.as_mut(),
                &crate::live::folders(world.main, world.source),
            );
        }
        engine.load(&QUrl::from(world.main));
    }
    if failed.load(Ordering::Relaxed) {
        // Right after an update: the version before goes back in at once.
        if TRYING.load(Ordering::Relaxed)
            && let Some(trial) = install::roll_back(&runtime().app)
        {
            after_roll_back(&trial, &manifest.id, &runtime().data_dir);
        }
        leave(1);
    }
    if TRYING.load(Ordering::Relaxed) {
        // Up and drawing for a little while: the update stays.
        runtime().tokio.spawn(async {
            tokio::time::sleep(std::time::Duration::from_secs(10)).await;
            install::started_well(&runtime().app);
            TRYING.store(false, Ordering::Relaxed);
        });
    }
    let code = match gui.as_mut() {
        Some(gui) => gui.exec(),
        None => 1,
    };
    drop(engine);
    leave(code)
}
