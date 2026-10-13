//! `SolBackend`: the one QObject the screens talk to. A QML singleton, so
//! every screen sees the same connection. Its properties mirror
//! `orbit::link::Link` (the status, what waits to be sent, the app's own
//! updates) as JSON; commands go through `call` and come back through the
//! `replied` signal, which `Sol.qml` turns into promises.

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        /// The world this app is, e.g. `terra`.
        #[qproperty(QString, world)]
        /// `orbit::link::Status`, as JSON.
        #[qproperty(QString, status)]
        /// Changes made here that haven't reached Sol yet.
        #[qproperty(i32, unsent)]
        /// `orbit::updates::Status`, as JSON.
        #[qproperty(QString, app)]
        /// `orbit::link::Kept`, as JSON: how many writes are kept aside
        /// (conflicts, rejected, from an earlier pairing).
        #[qproperty(QString, kept)]
        /// Why the local copy didn't open (`{ problem, path, detail }`), as
        /// JSON; "" when it did.
        #[qproperty(QString, problem)]
        /// Bumped when the world's settings change in Sol.
        #[qproperty(i32, settings_version, cxx_name = "settingsVersion")]
        /// Whether this copy runs without a window (a moon with its planet).
        #[qproperty(bool, background)]
        /// `SOL_SHOT=<file.png>`: save a picture of the window once its page is
        /// ready, or after `shotAfter` ms at the latest, and quit. While a
        /// batch (`shots`) runs, the picture being taken now.
        #[qproperty(QString, shot)]
        #[qproperty(i32, shot_after, cxx_name = "shotAfter")]
        /// `SOL_SHOT_PATH=/settings`: the page to open before the picture
        /// (in a batch, the current picture's).
        #[qproperty(QString, shot_path, cxx_name = "shotPath")]
        /// `SOL_SHOTS`: many pictures in one run, `<png>=<path>` each, one a
        /// line or `;` apart (or a file holding them).
        #[qproperty(QString, shots)]
        /// `SOL_SHOT_READY=0`: shoot after `shotAfter` ms, not when the page is ready.
        #[qproperty(bool, shot_ready, cxx_name = "shotReady")]
        /// `SOL_SHOT_CALM=1`: pictures without the arrivals: everything takes
        /// its place at once, so a picture waits for nothing to move.
        #[qproperty(bool, shot_calm, cxx_name = "shotCalm")]
        /// `SOL_PREVIEW`: the Shell without pairing, on a throwaway local copy.
        #[qproperty(bool, preview)]
        /// The app sits in the tray: closing the window only hides it.
        #[qproperty(bool, tray)]
        /// `SOL_FPS=1`: the window says how many frames it paints a second.
        #[qproperty(bool, fps)]
        /// `SOL_DRIVE=<file.qml>`: a script that drives the window, to check it end to end.
        #[qproperty(QString, drive)]
        /// `SOL_CALM=1`: this run with less motion, whatever the device's setting says.
        #[qproperty(bool, calm)]
        /// `SOL_FLAVOUR=<world>`: another world's flavour worn for this run (the gallery's
        /// pictures of each); "" is the window's own (`Theme.lookWorld`).
        #[qproperty(QString, flavour)]
        /// The look's pictures on this computer (`~/.local/share/sol-yozora/`), as a JSON list of
        /// file names; `[]` without the folder (`Theme.yozoraArt`). Set again once missing ones have come.
        #[qproperty(QString, look_art, cxx_name = "lookArt")]
        /// The page to open first (`--open /title?key=x`, or asked for while starting).
        #[qproperty(QString, open_path, cxx_name = "openPath")]
        /// `SOL_TRACE`: the window writes its timings (`trace`) for `scripts/measure.sh`.
        #[qproperty(bool, trace_on, cxx_name = "traceOn")]
        /// The moons this app carries, as JSON by id: `{ luna: { name,
        /// status, unsent, kept, problem, settingsVersion } }`, each as the
        /// app's own are above.
        #[qproperty(QString, moons)]
        type SolBackend = super::Backend;

        /// `call` for a world this app carries (`luna`); "" is the app's own.
        #[qinvokable]
        #[cxx_name = "callIn"]
        fn call_in(
            self: Pin<&mut Self>,
            world: &QString,
            id: i32,
            command: &QString,
            args: &QString,
        );

        /// `callSeen` for a world this app carries.
        #[qinvokable]
        #[cxx_name = "callSeenIn"]
        fn call_seen_in(
            self: Pin<&mut Self>,
            world: &QString,
            id: i32,
            key: &QString,
            command: &QString,
            args: &QString,
        );

        /// One timing line for `scripts/measure.sh`, with the time since the start.
        #[qinvokable]
        fn trace(&self, what: &QString);

        /// A carried world's manifest, as JSON ("" for none).
        #[qinvokable]
        #[cxx_name = "manifestOf"]
        fn manifest_of(&self, world: &QString) -> QString;

        /// Runs a command; the reply arrives as `replied(id, ok, body)`.
        #[qinvokable]
        fn call(self: Pin<&mut Self>, id: i32, command: &QString, args: &QString);

        /// Runs a command as `Sol.callSeen` does: what it replied last time on
        /// this device (kept under `key`) arrives first as `recalled(id,
        /// body)`, read off the window's thread; then `repeated(id)` when the
        /// fresh reply is the same, and `replied` as for `call`. A new reply
        /// is kept for next time.
        #[qinvokable]
        #[cxx_name = "callSeen"]
        fn call_seen(
            self: Pin<&mut Self>,
            id: i32,
            key: &QString,
            command: &QString,
            args: &QString,
        );

        /// The world's manifest (`sol-world.json`), as JSON.
        #[qinvokable]
        fn manifest(&self) -> QString;

        /// Opens a web address in the system browser.
        #[qinvokable]
        #[cxx_name = "openUrl"]
        fn open_url(&self, url: &QString);

        /// The window's last geometry, as JSON (`{}` the first time).
        #[qinvokable]
        #[cxx_name = "windowState"]
        fn window_state(&self) -> QString;

        #[qinvokable]
        #[cxx_name = "saveWindow"]
        fn save_window(&self, state: &QString);

        /// What a page was last shown (`remember`), for showing it again at
        /// once on the next start while fresh data comes; "" if nothing.
        #[qinvokable]
        fn recall(&self, key: &QString) -> QString;

        /// Keeps what a page shows, as JSON, for `recall`; written only when
        /// it changed, off the window's thread.
        #[qinvokable]
        fn remember(&self, key: &QString, json: &QString);

        /// A count for the app's icon and the tray (cards due, habits left),
        /// with what it counts; 0 for none.
        #[qinvokable]
        #[cxx_name = "setBadge"]
        fn set_badge(&self, count: i32, what: &QString);

        /// A command's reply: the JSON it returned, or why it didn't.
        #[qsignal]
        fn replied(self: Pin<&mut Self>, id: i32, ok: bool, body: QString);

        /// What a `callSeen` command replied last time on this device, before
        /// the fresh reply.
        #[qsignal]
        fn recalled(self: Pin<&mut Self>, id: i32, body: QString);

        /// A `callSeen` command's fresh reply is what it replied last time
        /// (sent just before `replied`).
        #[qsignal]
        fn repeated(self: Pin<&mut Self>, id: i32);

        /// Documents changed, here or elsewhere: the collections, as a JSON list.
        #[qsignal]
        fn changed(self: Pin<&mut Self>, collections: QString);

        /// Another copy was started: the window should come up.
        #[qsignal]
        fn activate(self: Pin<&mut Self>);

        /// Open a page another app asked for (`/title?key=x`), and come up.
        #[qsignal]
        #[cxx_name = "openRequested"]
        fn open_requested(self: Pin<&mut Self>, path: QString);

        /// Quick capture's key was pressed: the window opens the line over the desktop.
        #[qsignal]
        #[cxx_name = "captureRequested"]
        fn capture_requested(self: Pin<&mut Self>);

        /// Quit asked from outside the window (the tray, an update, a restart):
        /// the window closes for good, then the app leaves.
        #[qsignal]
        #[cxx_name = "quitRequested"]
        fn quit_requested(self: Pin<&mut Self>);

        /// Something the person should hear: a notice for the screens.
        #[qsignal]
        fn notice(self: Pin<&mut Self>, title: QString, body: QString, tone: QString);

        /// A world's own event for its screens (`sol_quick::emit`): a name and JSON.
        #[qsignal]
        #[cxx_name = "worldEvent"]
        fn world_event(self: Pin<&mut Self>, name: QString, data: QString);

        /// A carried world's own event (`sol_quick::emit_in`): its id, a name and JSON.
        #[qsignal]
        #[cxx_name = "eventIn"]
        fn event_in(self: Pin<&mut Self>, world: QString, name: QString, data: QString);

        /// Documents changed in a carried world: its id and the collections, as a JSON list.
        #[qsignal]
        #[cxx_name = "changedIn"]
        fn changed_in(self: Pin<&mut Self>, world: QString, collections: QString);
    }

    impl cxx_qt::Threading for SolBackend {}
    impl cxx_qt::Initialize for SolBackend {}
}

use core::pin::Pin;
use std::sync::atomic::Ordering;

use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::QString;
use orbit::link::Update;
use tokio::sync::broadcast::error::{RecvError, TryRecvError};

use crate::app::{self, Runtime, ToWindow};
use crate::look_art;

pub struct Backend {
    world: QString,
    status: QString,
    unsent: i32,
    app: QString,
    kept: QString,
    problem: QString,
    settings_version: i32,
    background: bool,
    shot: QString,
    shot_after: i32,
    shot_path: QString,
    shots: QString,
    shot_ready: bool,
    shot_calm: bool,
    preview: bool,
    tray: bool,
    fps: bool,
    drive: QString,
    calm: bool,
    flavour: QString,
    look_art: QString,
    open_path: QString,
    trace_on: bool,
    moons: QString,
    /// What `moons` says, kept to change one world's part at a time.
    moon_state: serde_json::Map<String, serde_json::Value>,
}

impl Default for Backend {
    fn default() -> Self {
        let rt = app::runtime();
        let shots = shot_list();
        // The first of many pictures is the one to start with, as if it were the only one,
        // so the window comes up as that picture wants it (a `_problem` never loads the Shell).
        let first = shots
            .split(['\n', ';'])
            .map(str::trim)
            .find(|l| !l.is_empty() && !l.starts_with('#'))
            .and_then(|l| l.split_once('='))
            .map(|(png, path)| (png.trim().to_owned(), path.trim().to_owned()));
        let (shot, shot_path) = first.unwrap_or_else(|| {
            let var = |name| std::env::var(name).unwrap_or_default();
            (var("SOL_SHOT"), var("SOL_SHOT_PATH"))
        });
        Self {
            world: QString::from(rt.link.world()),
            status: json(&rt.link.status()),
            unsent: 0,
            app: json(&rt.updates.status()),
            kept: json(&orbit::link::Kept::default()),
            problem: QString::from(rt.problem.as_deref().unwrap_or_default()),
            settings_version: 0,
            background: rt.background,
            shot: QString::from(&shot),
            shot_after: std::env::var("SOL_SHOT_AFTER")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(8000),
            shot_path: QString::from(&shot_path),
            shots: QString::from(&shots),
            shot_ready: std::env::var("SOL_SHOT_READY").map_or(true, |v| v != "0"),
            shot_calm: std::env::var("SOL_SHOT_CALM").is_ok_and(|v| v != "0"),
            preview: rt.preview,
            tray: rt.tray.load(Ordering::Relaxed),
            fps: std::env::var_os("SOL_FPS").is_some(),
            drive: QString::from(&std::env::var("SOL_DRIVE").unwrap_or_default()),
            calm: std::env::var_os("SOL_CALM").is_some(),
            flavour: QString::from(&std::env::var("SOL_FLAVOUR").unwrap_or_default()),
            look_art: QString::from(&look_art_json()),
            open_path: QString::from(&app::take_pending_open().unwrap_or_default()),
            trace_on: std::env::var_os("SOL_TRACE").is_some(),
            moons: QString::from("{}"),
            moon_state: serde_json::Map::new(),
        }
    }
}

/// `SOL_SHOTS`: the list itself, or what the file it names holds.
fn shot_list() -> String {
    let list = std::env::var("SOL_SHOTS").unwrap_or_default();
    let file = std::path::Path::new(list.trim());
    if !list.contains('=') && file.is_file() {
        return std::fs::read_to_string(file).unwrap_or_default();
    }
    list
}

/// A screen's command, started: its reply as `(ok, JSON or why not)`. A
/// command that panics still answers, so the screen's promise settles.
fn run(command: &QString, args: &QString) -> impl Future<Output = (bool, String)> + use<> {
    run_in("", command, args)
}

/// The same for `world` (a moon the app carries; "" for its own).
fn run_in(
    world: &str,
    command: &QString,
    args: &QString,
) -> impl Future<Output = (bool, String)> + use<> {
    let rt = app::runtime();
    let world = world.to_owned();
    let command = command.to_string();
    let args = args.to_string();
    let args = match serde_json::from_str(&args) {
        Ok(args) => args,
        Err(err) => {
            // Nothing passed reads as no arguments; anything else is the screen's mistake.
            if !args.trim().is_empty() {
                orbit::telemetry::damaged("a command's arguments from the screen", err);
            }
            serde_json::Value::Null
        }
    };
    let future = rt
        .world(&world)
        .map(|(link, commands, _)| commands.call(link.clone(), &command, args));
    let traced = rt.preview && std::env::var_os("SOL_TRACE").is_some();
    async move {
        let Some(future) = future else {
            return (false, format!("this app doesn't carry {world}"));
        };
        let at = std::time::Instant::now();
        let reply = match rt.tokio.spawn(future).await {
            Ok(Ok(json)) => (true, json),
            Ok(Err(why)) => (false, why),
            Err(_) => (false, format!("{command} failed inside the app")),
        };
        if traced {
            let w = if world.is_empty() {
                rt.app.world
            } else {
                world.as_str()
            };
            app::trace(&format!(
                "command {w}:{command} {}ms {}b",
                at.elapsed().as_millis(),
                reply.1.len()
            ));
        }
        reply
    }
}

fn json<T: serde::Serialize>(value: &T) -> QString {
    QString::from(&serde_json::to_string(value).unwrap_or_default())
}

impl cxx_qt::Initialize for qobject::SolBackend {
    /// Follows the link from now on: every update reaches the screens.
    fn initialize(self: Pin<&mut Self>) {
        let rt = app::runtime();
        let qt = self.qt_thread();
        // Everything Rust tells the window arrives on the Qt thread.
        rt.set_window({
            let qt = qt.clone();
            move |message| {
                let _ = qt.queue(move |mut me| match message {
                    ToWindow::Activate => me.activate(),
                    ToWindow::Quit => me.quit_requested(),
                    ToWindow::Tray(up) => me.set_tray(up),
                    ToWindow::Event(name, data) => me
                        .as_mut()
                        .world_event(QString::from(&name), QString::from(&data)),
                    ToWindow::Open(path) => me.open_requested(QString::from(&path)),
                    ToWindow::Capture => me.capture_requested(),
                    ToWindow::EventIn(world, name, data) => me.event_in(
                        QString::from(&world),
                        QString::from(&name),
                        QString::from(&data),
                    ),
                });
            }
        });
        // The look's pictures that are missing come in the background; once any
        // has, the window lists the folder again, so the ground and the
        // navigator appear without a restart. Never while pictures are taken:
        // they don't wait on the network.
        let shooting = ["SOL_SHOT", "SOL_SHOTS"]
            .iter()
            .any(|v| std::env::var_os(v).is_some_and(|s| !s.is_empty()));
        if let (false, Some(folder)) = (shooting, look_art::folder()) {
            let qt = qt.clone();
            rt.tokio.spawn(async move {
                if look_art::fetch_missing(&folder).await > 0 {
                    let art = look_art_json();
                    let _ = qt.queue(move |me| me.set_look_art(QString::from(&art)));
                }
            });
        }
        // Each carried moon is followed the same way, into `moons`.
        for c in &rt.carried {
            follow_moon(c, qt.clone());
        }
        // Subscribed before reading anything, so nothing between is missed.
        let mut updates = rt.link.subscribe();
        rt.tokio.spawn(async move {
            let link = &rt.link;
            let status = link.status();
            let app_status = rt.updates.status();
            let kept = link.kept().await.unwrap_or_default();
            let _ = qt.queue(move |mut me| {
                me.as_mut().set_status(json(&status));
                me.as_mut().set_kept(json(&kept));
                me.set_app(json(&app_status));
            });
            loop {
                // Every update waiting, then what is left to send, once.
                let mut batch = Vec::new();
                let mut lagged = false;
                match updates.recv().await {
                    Ok(update) => batch.push(update),
                    Err(RecvError::Lagged(_)) => lagged = true,
                    Err(RecvError::Closed) => return,
                }
                loop {
                    match updates.try_recv() {
                        Ok(update) => batch.push(update),
                        Err(TryRecvError::Lagged(_)) => lagged = true,
                        Err(TryRecvError::Empty | TryRecvError::Closed) => break,
                    }
                }
                if lagged {
                    // Fell behind a burst: the status as it is now, and the
                    // screens read everything again.
                    batch.push(Update::Status(link.status()));
                    batch.push(Update::Changed(Vec::new()));
                }
                let unsent = link.unsent().await.unwrap_or(0) as i32;
                let _ = qt.queue(move |mut me| {
                    me.as_mut().set_unsent(unsent);
                    for update in batch {
                        me.as_mut().apply(update);
                    }
                });
            }
        });
    }
}

/// Follows a carried moon's link: its status, unsent writes, kept writes and
/// settings into `moons`, its changes as `changedIn`.
fn follow_moon(c: &'static app::Carried, qt: cxx_qt::CxxQtThread<qobject::SolBackend>) {
    let rt = app::runtime();
    let world = c.world.clone();
    let mut updates = c.link.subscribe();
    {
        let (world, problem) = (world.clone(), c.problem.clone());
        let name = c.name.clone();
        let _ = qt.queue(move |me| {
            let problem = problem
                .and_then(|p| serde_json::from_str(&p).ok())
                .unwrap_or(serde_json::Value::Null);
            me.set_moon(
                &world,
                &[
                    ("name", name.into()),
                    ("problem", problem),
                    ("settingsVersion", 0.into()),
                ],
            );
        });
    }
    rt.tokio.spawn(async move {
        let link = &c.link;
        let status = serde_json::to_value(link.status()).unwrap_or_default();
        let kept = serde_json::to_value(link.kept().await.unwrap_or_default()).unwrap_or_default();
        let unsent = link.unsent().await.unwrap_or(0);
        {
            let world = world.clone();
            let _ = qt.queue(move |me| {
                me.set_moon(
                    &world,
                    &[
                        ("status", status),
                        ("kept", kept),
                        ("unsent", unsent.into()),
                    ],
                );
            });
        }
        loop {
            let mut batch = Vec::new();
            match updates.recv().await {
                Ok(update) => batch.push(update),
                Err(RecvError::Lagged(_)) => {
                    batch.push(Update::Status(link.status()));
                    batch.push(Update::Changed(Vec::new()));
                }
                Err(RecvError::Closed) => return,
            }
            while let Ok(update) = updates.try_recv() {
                batch.push(update);
            }
            let unsent = link.unsent().await.unwrap_or(0);
            let world = world.clone();
            let _ = qt.queue(move |mut me| {
                let mut fields = vec![("unsent", unsent.into())];
                for update in batch {
                    match update {
                        Update::Status(s) => {
                            fields.push(("status", serde_json::to_value(s).unwrap_or_default()))
                        }
                        Update::Kept(k) => {
                            fields.push(("kept", serde_json::to_value(k).unwrap_or_default()))
                        }
                        Update::Settings => {
                            let n = me
                                .rust()
                                .moon_state
                                .get(&world)
                                .and_then(|w| w["settingsVersion"].as_i64())
                                .unwrap_or(0);
                            fields.push(("settingsVersion", (n + 1).into()));
                        }
                        Update::Changed(collections) => me
                            .as_mut()
                            .changed_in(QString::from(&world), json(&collections)),
                        Update::App(_) => {}
                    }
                }
                me.set_moon(&world, &fields);
            });
        }
    });
}

impl qobject::SolBackend {
    /// Sets some of a carried world's part of `moons`.
    fn set_moon(mut self: Pin<&mut Self>, world: &str, fields: &[(&str, serde_json::Value)]) {
        let text = {
            let mut me = self.as_mut().rust_mut();
            let entry = me
                .moon_state
                .entry(world.to_owned())
                .or_insert_with(|| serde_json::json!({}));
            for (k, v) in fields {
                entry[*k] = v.clone();
            }
            serde_json::to_string(&me.moon_state).unwrap_or_default()
        };
        self.set_moons(QString::from(&text));
    }

    fn apply(mut self: Pin<&mut Self>, update: Update) {
        match update {
            Update::Status(status) => self.set_status(json(&status)),
            Update::Changed(collections) => self.changed(json(&collections)),
            Update::Settings => {
                let n = *self.settings_version() + 1;
                self.set_settings_version(n);
            }
            Update::Kept(kept) => self.set_kept(json(&kept)),
            Update::App(status) => {
                self.as_mut().set_app(json(&status));
                // Once per version: a newer one is out, or one was put in place quietly.
                if let Some(news) = app::news(&status) {
                    self.notice(
                        QString::from("Update"),
                        QString::from(&news),
                        QString::from("info"),
                    );
                }
            }
        }
    }

    pub fn call(self: Pin<&mut Self>, id: i32, command: &QString, args: &QString) {
        let rt = app::runtime();
        let qt = self.qt_thread();
        let reply = run(command, args);
        rt.tokio.spawn(async move {
            let (ok, body) = reply.await;
            let _ = qt.queue(move |me| me.replied(id, ok, QString::from(&body)));
        });
    }

    pub fn call_seen(
        self: Pin<&mut Self>,
        id: i32,
        key: &QString,
        command: &QString,
        args: &QString,
    ) {
        let rt = app::runtime();
        let qt = self.qt_thread();
        let reply = run(command, args);
        let key = key.to_string();
        rt.tokio.spawn(async move {
            let first = qt.clone();
            let (ok, body, same) =
                crate::seen::through(rt.data_dir.clone(), key, reply, move |kept| {
                    let _ = first.queue(move |me| me.recalled(id, QString::from(&kept)));
                })
                .await;
            let _ = qt.queue(move |mut me| {
                if same {
                    me.as_mut().repeated(id);
                }
                me.replied(id, ok, QString::from(&body))
            });
        });
    }

    pub fn manifest(&self) -> QString {
        QString::from(app::runtime().manifest_json.as_str())
    }

    pub fn call_in(
        self: Pin<&mut Self>,
        world: &QString,
        id: i32,
        command: &QString,
        args: &QString,
    ) {
        let rt = app::runtime();
        let qt = self.qt_thread();
        let reply = run_in(&world.to_string(), command, args);
        rt.tokio.spawn(async move {
            let (ok, body) = reply.await;
            let _ = qt.queue(move |me| me.replied(id, ok, QString::from(&body)));
        });
    }

    pub fn call_seen_in(
        self: Pin<&mut Self>,
        world: &QString,
        id: i32,
        key: &QString,
        command: &QString,
        args: &QString,
    ) {
        let rt = app::runtime();
        let world = world.to_string();
        let Some((_, _, dir)) = rt.world(&world) else {
            return self.call_in(&QString::from(&world), id, command, args);
        };
        let dir = dir.to_owned();
        let qt = self.qt_thread();
        let reply = run_in(&world, command, args);
        let key = key.to_string();
        rt.tokio.spawn(async move {
            let first = qt.clone();
            let (ok, body, same) = crate::seen::through(dir, key, reply, move |kept| {
                let _ = first.queue(move |me| me.recalled(id, QString::from(&kept)));
            })
            .await;
            let _ = qt.queue(move |mut me| {
                if same {
                    me.as_mut().repeated(id);
                }
                me.replied(id, ok, QString::from(&body))
            });
        });
    }

    pub fn trace(&self, what: &QString) {
        app::trace(&what.to_string());
    }

    pub fn manifest_of(&self, world: &QString) -> QString {
        let world = world.to_string();
        let rt = app::runtime();
        QString::from(
            rt.carried
                .iter()
                .find(|c| c.world == world)
                .map_or("", |c| c.manifest_json.as_str()),
        )
    }

    pub fn open_url(&self, url: &QString) {
        let _ = open::that_detached(url.to_string());
    }

    pub fn window_state(&self) -> QString {
        QString::from(&Runtime::read_window().unwrap_or_else(|| "{}".into()))
    }

    pub fn save_window(&self, state: &QString) {
        Runtime::write_window(&state.to_string());
    }

    pub fn recall(&self, key: &QString) -> QString {
        QString::from(&crate::seen::recall(&key.to_string()).unwrap_or_default())
    }

    pub fn remember(&self, key: &QString, json: &QString) {
        let (key, json) = (key.to_string(), json.to_string());
        app::runtime()
            .tokio
            .spawn_blocking(move || crate::seen::remember(&key, &json));
    }

    pub fn set_badge(&self, count: i32, what: &QString) {
        crate::tray::badge(count.max(0) as u32, &what.to_string());
    }
}

/// The pictures the look stands on, as a JSON list of file names: the `.jpg` and `.png`
/// files in `~/.local/share/sol-yozora/`, read as the window opens and again once the
/// missing ones have come (`look_art`).
fn look_art_json() -> String {
    let files = look_art::folder()
        .map(|f| look_art::list(&f))
        .unwrap_or_default();
    serde_json::to_string(&files).unwrap_or_else(|_| "[]".into())
}
