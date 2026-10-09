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
    link::{Config, Handler, Link, Status, Tokens},
    moons,
    updates::{self, Next, Updates},
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
    dyn Fn(Link) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), String>> + Send>>
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
    /// Started by its planet: no window, just the work.
    pub background: bool,
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

/// Where `remember` keeps what a page last showed: a file per key, named
/// by a stable hash of it (FNV-1a), under the app's data folder.
fn seen_file(key: &str) -> PathBuf {
    let hash = key.bytes().fold(0xcbf2_9ce4_8422_2325_u64, |h, b| {
        (h ^ u64::from(b)).wrapping_mul(0x0100_0000_01b3)
    });
    runtime()
        .data_dir
        .join("seen")
        .join(format!("{hash:016x}.json"))
}

/// Forgets what pages showed that nothing has shown for 30 days (a key per
/// day, like a diary's page, would otherwise keep every day).
pub(crate) fn prune_seen() {
    let Ok(entries) = std::fs::read_dir(runtime().data_dir.join("seen")) else {
        return;
    };
    let month = std::time::Duration::from_secs(30 * 24 * 3600);
    for entry in entries.flatten() {
        let old = entry
            .metadata()
            .and_then(|m| m.modified())
            .is_ok_and(|t| t.elapsed().is_ok_and(|age| age > month));
        if old {
            let _ = std::fs::remove_file(entry.path());
        }
    }
}

/// What a page last showed, if it was kept.
pub(crate) fn recall(key: &str) -> Option<String> {
    std::fs::read_to_string(seen_file(key)).ok()
}

/// Keeps what a page shows; nothing is written when it is what was kept.
pub(crate) fn remember(key: &str, json: &str) {
    let path = seen_file(key);
    if std::fs::read_to_string(&path).is_ok_and(|kept| kept == json) {
        // Still shown: kept from pruning (its date moved on once a day at most).
        let day = std::time::Duration::from_secs(24 * 3600);
        if let Ok(file) = std::fs::File::options().append(true).open(&path)
            && file
                .metadata()
                .and_then(|m| m.modified())
                .is_ok_and(|t| t.elapsed().is_ok_and(|age| age > day))
        {
            let _ = file.set_modified(std::time::SystemTime::now());
        }
        return;
    }
    let part = path.with_extension("part");
    let wrote = path
        .parent()
        .map(std::fs::create_dir_all)
        .unwrap_or(Ok(()))
        .and_then(|()| std::fs::write(&part, json))
        .and_then(|()| std::fs::rename(&part, &path));
    if let Err(e) = wrote {
        tracing::warn!("couldn't keep what {} showed: {e}", path.display());
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
    match std::env::consts::OS {
        os @ ("linux" | "windows" | "macos") => Some(os.into()),
        _ => None,
    }
}

/// Where the desktop starts the app at login: `~/.config/autostart/sol-<world>.desktop`.
fn autostart_entry(app: &App) -> Option<PathBuf> {
    Some(
        dirs::config_dir()?
            .join("autostart")
            .join(format!("{}.desktop", app.bin_name())),
    )
}

/// The installed binary, which is the one that can start with the computer.
fn installed_bin(app: &App) -> Option<PathBuf> {
    match install::here(app) {
        install::Here::Installed { path, .. } => Some(path),
        _ => None,
    }
}

/// Whether the app starts with the computer; None when this copy can't.
fn autostart(app: &App) -> Option<bool> {
    installed_bin(app)?;
    Some(autostart_entry(app)?.exists())
}

fn set_autostart(app: &App, on: bool) -> Result<(), String> {
    use crate::commands::say;
    let bin = installed_bin(app).ok_or("only the installed copy starts with the computer")?;
    let path = autostart_entry(app).ok_or("no config folder for autostart")?;
    if on {
        std::fs::create_dir_all(path.parent().ok_or("no autostart folder")?).map_err(say)?;
        std::fs::write(
            &path,
            format!(
                "[Desktop Entry]\nType=Application\nName={}\nExec=\"{}\" --background\nIcon={}\nTerminal=false\nX-GNOME-Autostart-enabled=true\n",
                app.name,
                bin.display(),
                app.bin_name(),
            ),
        )
        .map_err(say)?;
    } else if path.exists() {
        std::fs::remove_file(&path).map_err(say)?;
    }
    Ok(())
}

/// What the app is for, in a word or three: `role` in sol-world.json
/// ("Habits and diary"). Sol doesn't read it; the app menu and the tray do.
fn role(manifest_json: &str) -> Option<String> {
    serde_json::from_str::<serde_json::Value>(manifest_json)
        .ok()?
        .get("role")?
        .as_str()
        .map(str::trim)
        .filter(|r| !r.is_empty())
        .map(str::to_owned)
}

fn make_app(world: &World, manifest: &WorldManifest) -> App {
    let leak = |s: &str| -> &'static str { Box::leak(s.to_owned().into_boxed_str()) };
    // In the app menu with what it is for, so a planet's name needn't be remembered.
    let name = match role(world.manifest) {
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
        pubkey: Some(world.update_key.trim()).filter(|k| !k.is_empty()),
    }
}

/// `--install`, `--uninstall` and `--version` from a terminal, before any window opens.
fn command_line(app: &App, name: &str, parent: Option<&str>) -> Option<i32> {
    let arg = std::env::args().nth(1)?;
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
        "--version" => Ok(format!("{name} {}", app.version)),
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

/// The commands every world shares: the connection, the manifest, doors,
/// the app's own updates and installation.
fn shared(commands: &mut Commands, app: App, parent: Option<String>) {
    use crate::commands::say;

    #[derive(serde::Deserialize)]
    struct Server {
        server: String,
    }
    #[derive(serde::Deserialize)]
    struct Which {
        world: String,
        /// A page there: `/title?key=x`.
        #[serde(default)]
        path: Option<String>,
    }
    #[derive(serde::Deserialize)]
    struct Auto {
        auto: bool,
    }
    #[derive(serde::Deserialize)]
    struct On {
        on: bool,
    }

    #[derive(serde::Deserialize)]
    struct Notify {
        title: String,
        #[serde(default)]
        body: String,
        /// A button, as `[id, label]`; pressing it is a `notified` event.
        action: Option<(String, String)>,
    }

    commands
        .add("notify", |_, a: Notify| async move {
            crate::desktop::notify(&a.title, &a.body, a.action).await
        })
        .add("connect", |link, a: Server| async move {
            link.connect(&a.server).await.map_err(say)
        })
        .add("cancel", |link, _: ()| async move {
            link.cancel();
            Ok(())
        })
        .add("forget", |link, _: ()| async move {
            link.forget().await.map_err(say)
        })
        .add("settings", |link, _: ()| async move {
            link.settings().await.map_err(say)
        })
        .add("open_in_sol", |link, _: ()| async move {
            let server = match link.status() {
                Status::Online { server, .. } | Status::Offline { server, .. } => server,
                _ => return Err("pair with Sol first".to_string()),
            };
            open::that_detached(format!("{server}/worlds/{}", link.world())).map_err(say)
        })
        .add(
            "doors",
            |_, _: ()| async move { Ok(orbit::doors::installed()) },
        )
        .add("open_world", |_, a: Which| async move {
            let Some(path) = a.path else {
                return orbit::doors::open(&a.world).map_err(say);
            };
            // Running: it opens the page. If not, it starts, and opens it once it answers.
            let knock = single::Knock::Open(path);
            let preview = runtime().preview;
            if single::knock(&a.world, preview, &knock) {
                return Ok(());
            }
            orbit::doors::open(&a.world).map_err(say)?;
            for _ in 0..40 {
                tokio::time::sleep(std::time::Duration::from_millis(250)).await;
                if single::knock(&a.world, preview, &knock) {
                    return Ok(());
                }
            }
            Err(format!("{} started, but didn't open the page", a.world))
        })
        .add("check_updates", |_, _: ()| async move {
            let updates = &runtime().updates;
            updates.check().await.map_err(say)?;
            Ok(updates.status())
        })
        .add("install_update", |_, _: ()| async move {
            let updates = &runtime().updates;
            // On Windows the setup takes over, so the app quits; elsewhere the
            // new version runs from the next start.
            if updates.install().await.map_err(say)? == Next::Quit {
                quit();
            }
            Ok(updates.status())
        })
        .add("set_auto_update", |_, a: Auto| async move {
            runtime().updates.set_auto(a.auto).await.map_err(say)
        });

    // Both start the installed copy, which waits for this one to leave.
    commands.add("restart", move |_, _: ()| async move {
        let path = match install::here(&app) {
            install::Here::Installed { path, .. } | install::Here::Loose { path } => path,
            _ => return Err::<(), String>("start the app again yourself".to_string()),
        };
        install::relaunch(&path).map_err(say)?;
        quit();
        Ok(())
    });
    // Starting with the computer, in the tray without a window: only the
    // installed copy can (null otherwise).
    commands.add(
        "autostart",
        move |_, _: ()| async move { Ok(autostart(&app)) },
    );
    commands.add("set_autostart", move |_, a: On| async move {
        set_autostart(&app, a.on)?;
        Ok(autostart(&app))
    });
    commands.add("install_app", move |_, _: ()| async move {
        let bin = install::install(&app).map_err(say)?;
        install::relaunch(&bin).map_err(say)?;
        quit();
        Ok::<(), String>(())
    });

    // A moon's place beside its planet: running with it, without a window.
    if let Some(parent) = parent {
        let (me, p) = (app, parent.clone());
        commands.add("with_planet", move |_, _: ()| {
            let (me, p) = (me, p.clone());
            async move { Ok(moons::enabled(&me, &p)) }
        });
        let (me, p) = (app, parent);
        commands.add("set_with_planet", move |_, a: On| {
            let (me, p) = (me, p.clone());
            async move {
                moons::set_enabled(&me, &p, a.on).map_err(say)?;
                Ok(moons::enabled(&me, &p))
            }
        });
    }
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
    single::leave();
    std::process::exit(code)
}

/// Runs the app. Never returns.
pub fn run(world: World) -> ! {
    let manifest: WorldManifest =
        serde_json::from_str(world.manifest).expect("sol-world.json is a world manifest");
    let app = make_app(&world, &manifest);
    let parent = manifest.parent.clone();
    orbit::telemetry::init();
    if let Some(code) = command_line(&app, &manifest.name, parent.as_deref()) {
        std::process::exit(code);
    }

    // Started by its planet: no window, just the work.
    let background = moons::in_background();
    let preview = std::env::var_os("SOL_PREVIEW").is_some();
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
        }
        single::Knock::Open(path) => open_page(path),
    });
    if let Some(path) = open_at {
        open_page(path);
    }
    if !first {
        std::process::exit(0);
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
    let data_dir = data_dir(&manifest.id);
    std::fs::create_dir_all(&data_dir).expect("the app's data folder");

    let link = tokio
        .block_on(Link::open(Config {
            world: manifest.id.clone(),
            dir: data_dir.clone(),
            device: device_name(),
            platform: platform(),
            version: world.version.into(),
            tokens: if preview {
                Tokens::File
            } else {
                Tokens::Keyring
            },
        }))
        .expect("the local copy opens");

    // The app-menu entry follows the installed version; updates come through Sol.
    install::refresh(&app);
    // Other apps on this computer can open this one from their sidebars.
    orbit::doors::settle(&app);
    let running = match &parent {
        // Its planet starts it from where it says it is.
        Some(parent) => {
            moons::settle(&app, parent);
            None
        }
        // A preview runs alone: the installed moons stay as they are.
        None if preview => None,
        // A planet's moons run whenever it does.
        None => moons::start(app.world),
    };
    if let Some(prepare) = world.prepare {
        prepare(&link, tokio.handle());
    }
    if preview
        && let Some(sample) = &world.sample
        && !data_dir.join("sampled").exists()
    {
        match tokio.block_on(sample(link.clone())) {
            Ok(()) => {
                let _ = std::fs::write(data_dir.join("sampled"), "");
            }
            Err(why) => tracing::warn!("sample data: {why}"),
        }
    }
    let updates = tokio.block_on(Updates::new(link.clone(), app));
    tokio.spawn(updates.clone().watch());

    let mut commands = world.commands;
    shared(&mut commands, app, parent.clone());

    let rt = Runtime {
        link: link.clone(),
        updates,
        commands,
        tokio: tokio.handle().clone(),
        manifest_json: world.manifest.to_owned(),
        name: manifest.name.clone(),
        role: role(world.manifest).unwrap_or_default(),
        app,
        background,
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

    let parent_started = parent.is_some() && background;
    // Without a window, a moon leaves once its planet has (or at once,
    // unpaired: there's nothing to do until it's opened and paired).
    if let Some(parent) = parent {
        let unpaired = matches!(link.status(), Status::Unpaired { .. });
        if background && unpaired {
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
    if !preview && !parent_started {
        crate::desktop::start(world.shortcuts);
    }
    runtime().tokio.spawn_blocking(prune_seen);
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
        engine.load(&QUrl::from(world.main));
    }
    if failed.load(Ordering::Relaxed) {
        leave(1);
    }
    let code = match gui.as_mut() {
        Some(gui) => gui.exec(),
        None => 1,
    };
    drop(engine);
    leave(code)
}
