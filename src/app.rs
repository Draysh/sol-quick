//! Starting a world's app: the command line, one copy at a time, the
//! connection to Sol (`orbit::link::Link`), installing and updating
//! itself, moons that run with their planet, and at last the window.

use std::{
    path::PathBuf,
    sync::{Arc, Mutex, OnceLock},
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
    /// first time, so the screens have something to show.
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

pub type Sample = Arc<dyn Fn(Link) -> crate::commands::Reply + Send + Sync>;

/// Everything the running app shares between Rust and the screens.
/// What carries a world event to the screens, once the window is up.
type Emitter = Box<dyn Fn(String, String) + Send + Sync>;

pub struct Runtime {
    pub link: Link,
    pub updates: Arc<Updates>,
    pub commands: Commands,
    pub tokio: tokio::runtime::Handle,
    pub manifest_json: String,
    pub app: App,
    /// A moon's planet, when this is a moon.
    pub parent: Option<String>,
    /// Started by its planet: no window, just the work.
    pub background: bool,
    /// `SOL_PREVIEW`: a throwaway local copy and the Shell without pairing, for working on screens.
    pub preview: bool,
    /// The app sits in the tray: closing the window hides it, Quit is in the tray's menu.
    pub tray: bool,
    pub data_dir: PathBuf,
    activate: Mutex<Option<Box<dyn Fn() + Send + Sync>>>,
    planet_gone: Mutex<Option<Box<dyn Fn() + Send + Sync>>>,
    emit: Mutex<Option<Emitter>>,
    told: Mutex<Option<String>>,
    _moons: Mutex<Option<moons::Running>>,
}

static RUNTIME: OnceLock<Runtime> = OnceLock::new();

pub fn runtime() -> &'static Runtime {
    RUNTIME.get().expect("sol_quick::run started the app")
}

impl Runtime {
    pub(crate) fn set_activate(&self, f: impl Fn() + Send + Sync + 'static) {
        *self.activate.lock().expect("activate lock") = Some(Box::new(f));
    }
    /// Brings the window up, from the tray or another copy knocking.
    pub fn activate_window(&self) {
        if let Some(f) = self.activate.lock().expect("activate lock").as_ref() {
            f();
        }
    }

    pub(crate) fn set_planet_gone(&self, f: impl Fn() + Send + Sync + 'static) {
        *self.planet_gone.lock().expect("gone lock") = Some(Box::new(f));
    }

    pub(crate) fn set_emit(&self, f: impl Fn(String, String) + Send + Sync + 'static) {
        *self.emit.lock().expect("emit lock") = Some(Box::new(f));
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
fn device_name() -> String {
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

fn make_app(world: &World, manifest: &WorldManifest) -> App {
    let leak = |s: &str| -> &'static str { Box::leak(s.to_owned().into_boxed_str()) };
    App {
        world: leak(&manifest.id),
        name: leak(&manifest.name),
        comment: leak(&manifest.tagline),
        version: world.version,
        wm_class: world.bin,
        icons: world.icons,
        pubkey: Some(world.update_key.trim()).filter(|k| !k.is_empty()),
    }
}

/// `--install` and `--uninstall` from a terminal, before any window opens.
fn command_line(app: &App, parent: Option<&str>) -> Option<i32> {
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
        "--version" => Ok(format!("{} {}", app.name, app.version)),
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
        /// A button: `{ id, label }`.
        action: Option<(String, String)>,
    }

    commands
        .add("notify", |_, a: Notify| async move {
            crate::desktop::notify(&a.title, &a.body, a.action)
        })
        .add("status", |link, _: ()| async move { Ok(link.status()) })
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
        .add("manifest", |_, _: ()| async move {
            serde_json::from_str::<serde_json::Value>(&runtime().manifest_json).map_err(say)
        })
        .add("settings", |link, _: ()| async move {
            link.settings().await.map_err(say)
        })
        .add("unsent", |link, _: ()| async move {
            link.unsent().await.map_err(say)
        })
        .add("open_in_sol", |link, _: ()| async move {
            let server = match link.status() {
                Status::Online { server, .. } | Status::Offline { server, .. } => server,
                _ => return Err("pair with Sol first".to_string()),
            };
            open::that_detached(format!("{server}/worlds/{}", link.world())).map_err(say)
        })
        .add("open_url", |_, a: serde_json::Value| async move {
            let url = a["url"].as_str().unwrap_or_default().to_owned();
            open::that_detached(url).map_err(say)
        })
        .add(
            "doors",
            |_, _: ()| async move { Ok(orbit::doors::installed()) },
        )
        .add("open_world", |_, a: Which| async move {
            orbit::doors::open(&a.world).map_err(|e| format!("{e:#}"))
        })
        .add("updates", |_, _: ()| async move {
            Ok(runtime().updates.status())
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
            if updates.install().await.map_err(|e| format!("{e:#}"))? == Next::Quit {
                leave(0);
            }
            Ok(updates.status())
        })
        .add("set_auto_update", |_, a: Auto| async move {
            runtime().updates.set_auto(a.auto).await.map_err(say)
        });

    let me = app;
    commands.add("restart", move |_, _: ()| {
        let me = me;
        async move {
            let path = match install::here(&me) {
                install::Here::Installed { path, .. } | install::Here::Loose { path } => path,
                _ => return Err::<(), String>("start the app again yourself".to_string()),
            };
            install::relaunch(&path).map_err(say)?;
            leave(0)
        }
    });
    let me = app;
    commands.add("install_app", move |_, _: ()| {
        let me = me;
        async move {
            let bin = install::install(&me).map_err(|e| format!("{e:#}"))?;
            install::relaunch(&bin).map_err(say)?;
            if bin.exists() {
                leave(0)
            }
            Ok::<(), String>(())
        }
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
        && let Some(f) = rt.emit.lock().expect("emit lock").as_ref()
        && let Ok(json) = serde_json::to_string(data)
    {
        f(name.to_owned(), json);
    }
}

/// Leaves cleanly: the single-instance door closes behind us.
pub fn leave(code: i32) -> ! {
    if let Some(rt) = RUNTIME.get() {
        single::leave(rt.link.world());
    }
    std::process::exit(code)
}

/// Runs the app. Never returns.
pub fn run(world: World) -> ! {
    let manifest: WorldManifest =
        serde_json::from_str(world.manifest).expect("sol-world.json is a world manifest");
    let app = make_app(&world, &manifest);
    let parent = manifest.parent.clone();
    if let Some(code) = command_line(&app, parent.as_deref()) {
        std::process::exit(code);
    }

    // Started by its planet: no window, just the work.
    let background = moons::in_background();
    // One copy at a time: a second one brings the first's window up and leaves.
    if single::already_running(&manifest.id, !background) {
        std::process::exit(0);
    }

    orbit::telemetry::init();
    let tokio = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .thread_name("sol-tokio")
        .build()
        .expect("a tokio runtime");
    let preview = std::env::var_os("SOL_PREVIEW").is_some();
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
        // A planet's moons run whenever it does.
        None => moons::start(app.world),
    };
    if preview
        && let Some(sample) = &world.sample
        && !data_dir.join("sampled").exists()
    {
        if let Err(why) = tokio.block_on(sample(link.clone())) {
            tracing::warn!("sample data: {why}");
        }
        let _ = std::fs::write(data_dir.join("sampled"), "");
    }
    if let Some(prepare) = world.prepare {
        prepare(&link, tokio.handle());
    }
    let updates = tokio.block_on(Updates::new(link.clone(), app));
    tokio.spawn(updates.clone().watch());

    let mut commands = world.commands;
    shared(&mut commands, app, parent.clone());
    let tray = !background && !preview;

    let rt = Runtime {
        link: link.clone(),
        updates,
        commands,
        tokio: tokio.handle().clone(),
        manifest_json: world.manifest.to_owned(),
        app,
        parent: parent.clone(),
        background,
        preview,
        tray,
        data_dir,
        activate: Mutex::new(None),
        planet_gone: Mutex::new(None),
        emit: Mutex::new(None),
        told: Mutex::new(None),
        _moons: Mutex::new(running),
    };
    if RUNTIME.set(rt).is_err() {
        panic!("sol_quick::run twice");
    }

    // Later copies knock here; the window answers.
    single::listen(&manifest.id, || {
        if let Some(f) = runtime().activate.lock().expect("activate lock").as_ref() {
            f();
        }
    });

    // Without a window, a moon leaves once its planet has (or at once,
    // unpaired: there's nothing to do until it's opened and paired).
    if let Some(parent) = parent.clone() {
        let unpaired = matches!(link.status(), Status::Unpaired { .. });
        if background && unpaired {
            leave(0);
        }
        tokio.spawn(async move {
            loop {
                moons::planet_gone(&parent).await;
                if let Some(f) = runtime().planet_gone.lock().expect("gone lock").as_ref() {
                    f();
                }
            }
        });
    }

    // The tray and the global shortcuts, beside the window.
    if tray {
        crate::desktop::start(world.tray, world.shortcuts, world.icons);
    }
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
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from(world.main));
    }
    let code = match gui.as_mut() {
        Some(gui) => gui.exec(),
        None => 1,
    };
    drop(engine);
    leave(code)
}
