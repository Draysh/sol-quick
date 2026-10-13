//! The start-up, in the order `run` takes it: the command line, one copy
//! at a time, an update's first start, the local copy and its link to Sol,
//! each moon the app carries (its door, its copy, its link), the app's place
//! on the computer (menu entry, doors, moons), the shared runtime, the tray
//! and shortcuts, and at last the window.

use std::{
    path::{Path, PathBuf},
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
};

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QString, QUrl};
use orbit::{
    WorldManifest,
    install::{self, App},
    link::{Config, Link, LocalCopyError, Status, Tokens},
    moons,
    updates::Updates,
};

use super::{
    BUILT_QT, Carried, Moon, RUNTIME, Runtime, STAND_IN, Sample, TRYING, ToWindow, World, data_dir,
    device_name, leave, open_page, quit, runtime,
};
use crate::single;

/// Runs the app. Never returns.
pub fn run(world: World) -> ! {
    run_with(world, Vec::new())
}

/// Runs a planet's app carrying its moons: each moon's pages in the window,
/// its work in this process, its own link and door. Never returns.
pub fn run_with(world: World, moons: Vec<Moon>) -> ! {
    let _ = super::STARTED.set(std::time::Instant::now());
    // This process is the app: its doors are the computer's, not a test's.
    single::use_the_computers_doors();
    let manifest: WorldManifest =
        serde_json::from_str(world.manifest).expect("sol-world.json is a world manifest");
    let mut app = make_app(&world, &manifest);
    let moons: Vec<(Moon, WorldManifest, App)> = moons
        .into_iter()
        .map(|moon| {
            let m: WorldManifest =
                serde_json::from_str(moon.manifest).expect("a moon's sol-world.json");
            let moon_app = moon_app(&moon, &m);
            (moon, m, moon_app)
        })
        .collect();
    // Started by a moon's name (the desktop's `sol-luna --do`, an older
    // planet starting it): that moon, inside this app.
    let as_moon = invoked_as(
        &moons
            .iter()
            .map(|(_, m, _)| m.id.as_str())
            .collect::<Vec<_>>(),
    );
    // First, and before anything is written: `--version` is how an update
    // is tried before it goes in.
    let moon_apps: Vec<App> = moons.iter().map(|(_, _, a)| *a).collect();
    if let Some(code) = match as_moon.and_then(|i| moons.get(i)) {
        Some((_, m, moon_app)) => desktop_line(moon_app, &m.name),
        None => None,
    }
    .or_else(|| command_line(&app, &manifest.name, &moon_apps))
    {
        std::process::exit(code);
    }
    app.qt = Some(running_qt());
    let preview = std::env::var_os("SOL_PREVIEW").is_some();
    orbit::telemetry::init_app(&log_file(&manifest.id, preview));
    let data_dir = data_dir(&manifest.id);
    // Started at login (or as a carried moon, by an older planet's app): no
    // window, just the work.
    let background = moons::in_background() || crate::autostart::at_login();
    let start_at = as_moon
        .and_then(|i| moons.get(i))
        .map(|(_, m, _)| format!("/{}", m.id));
    one_copy_at_a_time(&manifest.id, preview, background, start_at);
    count_the_start(&app, &manifest.id, &data_dir);

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

    let (link, problem) = open_link(&tokio, &manifest.id, world.version, &data_dir, preview);
    // Each moon: its door first (so no other copy opens its local copy too),
    // then its link, as the app's own.
    let mut carried = Vec::new();
    let mut handlers = Vec::new();
    for (moon, m, moon_app) in moons {
        let (c, handler) = carry(&tokio, moon, &m, &moon_app, app, preview);
        carried.push(c);
        handlers.push(handler);
    }
    let carried_ids: Vec<&str> = moon_apps.iter().map(|a| a.world).collect();
    let running = settle_on_the_computer(&app, preview || problem.is_some(), &carried_ids);
    if !preview {
        for moon_app in &moon_apps {
            take_the_moons_place(&app, moon_app);
        }
    }
    if let Some(prepare) = world.prepare {
        prepare(&link, tokio.handle());
    }
    if preview && problem.is_none() {
        fill_with_samples(&tokio, &link, world.sample.as_ref(), &data_dir);
    }
    let updates = tokio.block_on(Updates::new(link.clone(), app));
    tokio.spawn(updates.clone().watch());

    let mut commands = world.commands;
    crate::shared::add(&mut commands, app, manifest.collections.clone());

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
        carried,
    };
    if RUNTIME.set(rt).is_err() {
        panic!("sol_quick::run twice");
    }
    // What the desktop around the app shows of it (the bar, the terminal).
    crate::status::start(runtime());

    // The Sol tray and global shortcuts, for every app here but a preview
    // (one that started hidden, with the computer, too).
    if !preview {
        crate::tray::start(world.tray);
        crate::desktop::start(world.shortcuts);
    }
    runtime().tokio.spawn_blocking(crate::seen::prune);
    // Sync; the screens follow through `SolBackend`.
    link.start(world.handler);
    for (c, handler) in runtime().carried.iter().zip(handlers) {
        c.link.start(handler);
        if !preview {
            pair_through_the_planet(&c.link);
        }
    }

    let modules = MOON_MODULES.lock().map(|m| m.clone()).unwrap_or_default();
    show_the_window(&manifest, world.version, world.main, world.source, &modules)
}

/// Each carried moon's QML module and the checkout of its screens.
static MOON_MODULES: Mutex<Vec<(&'static str, &'static str)>> = Mutex::new(Vec::new());

/// A moon, carried: its door (taken over from its own app if that still
/// runs), its local copy and link, its prepared work and sample data, and
/// its commands with the shared ones on its link. Its handler starts with
/// the rest once the runtime is up.
fn carry(
    tokio: &tokio::runtime::Runtime,
    moon: Moon,
    m: &WorldManifest,
    moon_app: &App,
    planet: App,
    preview: bool,
) -> (Carried, std::sync::Arc<dyn orbit::link::Handler>) {
    if let Ok(mut modules) = MOON_MODULES.lock() {
        modules.push((moon.module, moon.source));
    }
    let id = m.id.clone();
    let data = data_dir(&id);
    let ours = moon_door(&id, preview) || (!preview && take_over(moon_app, &id));
    let (link, problem) = if ours {
        open_link(tokio, &id, moon.version, &data, preview)
    } else {
        // Its own app holds its copy and won't go: its pages say so.
        let (link, _) = open_link(
            tokio,
            &id,
            moon.version,
            &std::env::temp_dir().join(format!("sol-{id}-elsewhere-{}", std::process::id())),
            true,
        );
        let detail = format!(
            "{} is running in its own app; close it, and its pages are here from the next start.",
            m.name
        );
        let problem = serde_json::json!({ "problem": "elsewhere", "path": "", "detail": detail });
        (link, Some(problem.to_string()))
    };
    if let Some(prepare) = moon.prepare {
        prepare(&link, tokio.handle());
    }
    if preview && problem.is_none() {
        fill_with_samples(tokio, &link, moon.sample.as_ref(), &data);
    }
    let mut commands = moon.commands;
    crate::shared::add(&mut commands, planet, m.collections.clone());
    let carried = Carried {
        world: id,
        name: m.name.clone(),
        link,
        commands,
        manifest_json: moon.manifest.to_owned(),
        problem,
        data_dir: data,
    };
    (carried, moon.handler)
}

/// Claims a carried moon's door: `show` opens its pages, `open <p>` one of
/// them, `do`, `find` and `ask` go to its commands on its link, `capture`
/// opens the app's quick capture. False when another copy holds it.
fn moon_door(id: &str, preview: bool) -> bool {
    let world = id.to_owned();
    single::claim(id, preview, None, move |knock| match knock {
        single::Knock::Show => {
            open_page(format!("/{world}"));
            None
        }
        single::Knock::Open(path) => {
            open_page(format!("/{world}{}", if path == "/" { "" } else { &path }));
            None
        }
        single::Knock::Ask(command, _) if command == "capture" => Some(match RUNTIME.get() {
            Some(rt) if rt.tell(ToWindow::Capture) => Ok("\"open\"".into()),
            _ => Err("the app is still starting; try again in a moment".into()),
        }),
        single::Knock::Ask(command, args) => Some(
            match RUNTIME.get().and_then(|rt| Some((rt, rt.world(&world)?))) {
                Some((rt, (link, commands, _)))
                    if matches!(command.as_str(), "do" | "find" | "ask") =>
                {
                    rt.tokio
                        .block_on(commands.call(link.clone(), &command, args))
                }
                Some(_) => Err(format!("nothing answers {command:?} from the desktop")),
                None => Err("the app is still starting; try again in a moment".into()),
            },
        ),
    })
}

/// The moon's own app still runs (an earlier version, standalone): it is
/// asked to quit (it saves as it goes) and its door taken once it has gone,
/// within five seconds. False when it stays.
fn take_over(moon_app: &App, id: &str) -> bool {
    let pids = running_as(&moon_app.bin_name());
    if pids.is_empty() {
        return false;
    }
    for pid in &pids {
        tracing::info!(
            pid,
            "asking {}'s own app to quit: this app carries it now",
            id
        );
        let _ = std::process::Command::new("kill")
            .arg("-TERM")
            .arg(pid.to_string())
            .status();
    }
    for _ in 0..20 {
        std::thread::sleep(std::time::Duration::from_millis(250));
        if moon_door(id, false) {
            return true;
        }
    }
    tracing::warn!("{id}'s own app didn't quit; its pages wait for it");
    false
}

/// The processes (other than this one) started as `bin`.
fn running_as(bin: &str) -> Vec<u32> {
    let me = std::process::id();
    std::fs::read_dir("/proc")
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|e| e.file_name().to_str()?.parse::<u32>().ok())
        .filter(|&pid| pid != me)
        .filter(|pid| {
            std::fs::read(format!("/proc/{pid}/cmdline")).is_ok_and(|c| {
                let argv0 = c.split(|&b| b == 0).next().unwrap_or_default();
                use std::os::unix::ffi::OsStrExt;
                Path::new(std::ffi::OsStr::from_bytes(argv0))
                    .file_name()
                    .is_some_and(|n| n == bin)
            })
        })
        .collect()
}

/// An installed planet that carries `moon` takes the moon's own app away
/// (its menu entry and icons; `sol-<moon>` becomes a link to this app) and
/// its place at login. Done once; development builds and previews never.
fn take_the_moons_place(planet: &App, moon: &App) {
    let install::Here::Installed { path, .. } = install::here(planet) else {
        return;
    };
    match install::uninstall_other(moon, &path) {
        Ok(true) => tracing::info!(
            "{}'s own app is gone: {} carries it now",
            moon.world,
            planet.world
        ),
        Ok(false) => {}
        Err(err) => tracing::warn!(error = ?err, "couldn't take {}'s own app away", moon.world),
    }
    if crate::autostart::hand_over(moon, planet, &path) {
        tracing::info!(
            "{} starts with the computer now, for {}",
            planet.world,
            moon.world
        );
    }
}

/// A carried moon pairs through its planet, without a code, as soon as the
/// planet is paired (and again should it ever be unpaired while the planet is).
fn pair_through_the_planet(moon: &'static Link) {
    let rt = runtime();
    let planet = &rt.link;
    let mut updates = planet.subscribe();
    rt.tokio.spawn(async move {
        loop {
            let paired = matches!(
                planet.status(),
                Status::Online { .. } | Status::Offline { .. }
            );
            if paired && matches!(moon.status(), Status::Unpaired { .. }) {
                match moon.pair_through(planet).await {
                    Ok(_) => tracing::info!("{} paired through {}", moon.world(), planet.world()),
                    Err(err) => tracing::warn!(
                        "{} couldn't pair through {}: {err:#}",
                        moon.world(),
                        planet.world()
                    ),
                }
            }
            if updates.recv().await.is_err() {
                return;
            }
        }
    });
}

/// One copy at a time: a later one brings this one's window up and leaves.
/// `--open /title?key=x`: at that page (here, or in the copy already running).
fn one_copy_at_a_time(world: &str, preview: bool, background: bool, start_at: Option<String>) {
    // Started by a moon's name: at the moon's pages (or one of them).
    let open_at = std::env::args()
        .skip_while(|a| a != "--open")
        .nth(1)
        .filter(|p| p.starts_with('/'))
        .map(|p| match &start_at {
            Some(moon) => format!("{moon}{}", if p == "/" { "" } else { &p }),
            None => p,
        })
        .or(start_at);
    let knock = if background {
        None
    } else {
        Some(
            open_at
                .clone()
                .map_or(single::Knock::Show, single::Knock::Open),
        )
    };
    let first = single::claim(world, preview, knock, |knock| match knock {
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
}

/// A version just put in place by an update: this start counts, and one
/// that started before and never came up goes back to the one before.
/// (After the door: a second copy knocking isn't a start.)
fn count_the_start(app: &App, world: &str, data_dir: &Path) {
    match install::on_start(app) {
        install::Start::Normal => {}
        install::Start::Trying => TRYING.store(true, Ordering::Relaxed),
        install::Start::RolledBack(trial) => after_roll_back(&trial, world, data_dir),
    }
}

/// The local copy, and why it didn't open when it didn't (the `problem`
/// JSON the window shows).
fn open_link(
    tokio: &tokio::runtime::Runtime,
    world: &str,
    version: &str,
    data_dir: &Path,
    preview: bool,
) -> (Link, Option<String>) {
    let config = |dir: PathBuf, tokens| Config {
        world: world.to_owned(),
        dir,
        device: device_name(),
        platform: platform(),
        version: version.into(),
        tokens,
    };
    let tokens = if preview {
        Tokens::File
    } else {
        Tokens::Keyring
    };
    match tokio.block_on(Link::open(config(data_dir.to_owned(), tokens))) {
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
            let stand_in =
                std::env::temp_dir().join(format!("sol-{}-stand-in-{}", world, std::process::id()));
            if let Ok(mut kept) = STAND_IN.lock() {
                kept.push(stand_in.clone());
            }
            let link = tokio
                .block_on(Link::open(config(stand_in, Tokens::File)))
                .expect("an empty stand-in copy opens");
            let problem = serde_json::json!({ "problem": problem, "path": path, "detail": detail });
            (link, Some(problem.to_string()))
        }
    }
}

/// The app's place on this computer: its app-menu entry, autostart, the
/// doors other apps open it by, and its moons. A planet's hold on its moons'
/// "running" lock, when it starts them; `alone` (a preview, or a copy that
/// didn't open) starts none.
fn settle_on_the_computer(app: &App, alone: bool, carried: &[&str]) -> Option<moons::Running> {
    // The app-menu entry follows the installed version; updates come through Sol.
    install::refresh(app);
    crate::autostart::refresh(app);
    // Other apps on this computer can open this one from their sidebars.
    orbit::doors::settle(app);
    // A preview runs alone: the installed moons stay as they are; and a
    // copy that didn't open does nothing until the person chose. Otherwise
    // the lock older moons wait on is held, and a moon with an app of its
    // own still settled here starts with it (those it carries run in it).
    (!alone)
        .then(|| moons::start_except(app.world, carried))
        .flatten()
}

/// A preview's throwaway copy gets the world's sample data, once.
fn fill_with_samples(
    tokio: &tokio::runtime::Runtime,
    link: &Link,
    sample: Option<&Sample>,
    data_dir: &Path,
) {
    if let Some(sample) = sample
        && !data_dir.join("sampled").exists()
    {
        match tokio.block_on(sample(link.clone())) {
            Ok(()) => {
                let _ = std::fs::write(data_dir.join("sampled"), "");
            }
            Err(why) => tracing::warn!("sample data: {why:#}"),
        }
    }
}

/// The window. Qt owns the main thread from here, until the app leaves.
fn show_the_window(
    manifest: &WorldManifest,
    version: &str,
    main: &str,
    source: &'static str,
    moons: &[(&str, &str)],
) -> ! {
    let mut gui = QGuiApplication::new();
    // The .desktop file orbit::install writes: the desktop looks the icon and the name up under it.
    QGuiApplication::set_desktop_file_name(&QString::from(&format!("sol-{}", manifest.id)));
    if let Some(mut gui) = gui.as_mut() {
        gui.as_mut()
            .set_application_name(&QString::from(&manifest.name));
        gui.as_mut()
            .set_application_version(&QString::from(version));
        gui.as_mut()
            .set_organization_domain(&QString::from("sachi.digital"));
    }
    crate::fonts::load();
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
                &crate::live::folders(main, source, moons),
            );
        }
        engine.load(&QUrl::from(main));
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

fn platform() -> Option<String> {
    cfg!(target_os = "linux").then(|| "linux".into())
}

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

/// What a carried moon's own app was, so it can be found and taken away.
fn moon_app(moon: &Moon, manifest: &WorldManifest) -> App {
    let leak = |s: &str| -> &'static str { Box::leak(s.to_owned().into_boxed_str()) };
    App {
        world: leak(&manifest.id),
        name: leak(&manifest.name),
        comment: leak(&manifest.tagline),
        version: moon.version,
        wm_class: leak(&manifest.id),
        icons: moon.icons,
        pubkey: None,
        qt: None,
    }
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

/// The desktop's `--status`, `--do` and `--find` for a world, before any
/// window opens; None for anything else.
fn desktop_line(app: &App, name: &str) -> Option<i32> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let preview = std::env::var_os("SOL_PREVIEW").is_some();
    Some(match args.first()?.as_str() {
        "--status" => crate::status::print(app.world, name, preview),
        "--do" => crate::door::act(app.world, name, preview, &args[1..]),
        "--find" => crate::door::find(app.world, name, preview, &args[1..]),
        _ => return None,
    })
}

/// Which carried moon this process was started as (`sol-luna`, the link to
/// this app the moon's own app left), by its place among `moons`.
fn invoked_as(moons: &[&str]) -> Option<usize> {
    let argv0 = std::env::args_os().next()?;
    let name = Path::new(&argv0).file_name()?.to_str()?.to_owned();
    moons.iter().position(|m| name == format!("sol-{m}"))
}

/// `--install`, `--uninstall` and `--version` from a terminal, and the
/// desktop's `--status`, `--do` and `--find`, before any window opens.
fn command_line(app: &App, name: &str, moons: &[App]) -> Option<i32> {
    if let Some(code) = desktop_line(app, name) {
        return Some(code);
    }
    let args: Vec<String> = std::env::args().skip(1).collect();
    let arg = args.first()?.clone();
    let done = match arg.as_str() {
        "--install" => install::install(app).map(|bin| {
            // The other apps on this computer can open this one from now on.
            orbit::doors::settle_installed(app, &bin);
            // The moons it carries have no app of their own any more.
            for moon in moons {
                if let Err(err) = install::uninstall_other(moon, &bin) {
                    eprintln!("couldn't take {}'s own app away: {err:#}", moon.world);
                }
                crate::autostart::hand_over(moon, app, &bin);
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
