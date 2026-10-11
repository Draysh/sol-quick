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
        /// Bumped whenever documents change, here or on another device.
        #[qproperty(i32, changes)]
        /// Bumped when the world's settings change in Sol.
        #[qproperty(i32, settings_version, cxx_name = "settingsVersion")]
        /// Whether this copy runs without a window (a moon with its planet).
        #[qproperty(bool, background)]
        /// `SOL_SHOT=<file.png>`: save a picture of the window after `shotAfter` ms and quit.
        #[qproperty(QString, shot)]
        #[qproperty(i32, shot_after, cxx_name = "shotAfter")]
        /// `SOL_SHOT_PATH=/settings`: the page to open before the picture.
        #[qproperty(QString, shot_path, cxx_name = "shotPath")]
        /// `SOL_PREVIEW`: the Shell without pairing, on a throwaway local copy.
        #[qproperty(bool, preview)]
        /// The app sits in the tray: closing the window only hides it.
        #[qproperty(bool, tray)]
        /// `SOL_FPS=1`: the window says how many frames it paints a second.
        #[qproperty(bool, fps)]
        /// `SOL_DRIVE=<file.qml>`: a script that drives the window, to check it end to end.
        #[qproperty(QString, drive)]
        /// `SOL_LIGHT=night|day`: this run's light, whatever the device's setting says.
        #[qproperty(QString, light)]
        /// `SOL_CALM=1`: this run with less motion, whatever the device's setting says.
        #[qproperty(bool, calm)]
        /// The page to open first (`--open /title?key=x`, or asked for while starting).
        #[qproperty(QString, open_path, cxx_name = "openPath")]
        type SolBackend = super::Backend;

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

        /// A moon's planet has closed: without a window open, the moon leaves too.
        #[qsignal]
        #[cxx_name = "planetGone"]
        fn planet_gone(self: Pin<&mut Self>);

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
    }

    impl cxx_qt::Threading for SolBackend {}
    impl cxx_qt::Initialize for SolBackend {}
}

use core::pin::Pin;
use std::sync::atomic::Ordering;

use cxx_qt::Threading;
use cxx_qt_lib::QString;
use orbit::link::Update;
use tokio::sync::broadcast::error::{RecvError, TryRecvError};

use crate::app::{self, Runtime, ToWindow};

pub struct Backend {
    world: QString,
    status: QString,
    unsent: i32,
    app: QString,
    kept: QString,
    problem: QString,
    changes: i32,
    settings_version: i32,
    background: bool,
    shot: QString,
    shot_after: i32,
    shot_path: QString,
    preview: bool,
    tray: bool,
    fps: bool,
    drive: QString,
    light: QString,
    calm: bool,
    open_path: QString,
}

impl Default for Backend {
    fn default() -> Self {
        let rt = app::runtime();
        Self {
            world: QString::from(rt.link.world()),
            status: json(&rt.link.status()),
            unsent: 0,
            app: json(&rt.updates.status()),
            kept: json(&orbit::link::Kept::default()),
            problem: QString::from(rt.problem.as_deref().unwrap_or_default()),
            changes: 0,
            settings_version: 0,
            background: rt.background,
            shot: QString::from(&std::env::var("SOL_SHOT").unwrap_or_default()),
            shot_after: std::env::var("SOL_SHOT_AFTER")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(2500),
            shot_path: QString::from(&std::env::var("SOL_SHOT_PATH").unwrap_or_default()),
            preview: rt.preview,
            tray: rt.tray.load(Ordering::Relaxed),
            fps: std::env::var_os("SOL_FPS").is_some(),
            drive: QString::from(&std::env::var("SOL_DRIVE").unwrap_or_default()),
            light: QString::from(&std::env::var("SOL_LIGHT").unwrap_or_default()),
            calm: std::env::var_os("SOL_CALM").is_some(),
            open_path: QString::from(&app::take_pending_open().unwrap_or_default()),
        }
    }
}

/// A screen's command, started: its reply as `(ok, JSON or why not)`. A
/// command that panics still answers, so the screen's promise settles.
fn run(command: &QString, args: &QString) -> impl Future<Output = (bool, String)> + use<> {
    let rt = app::runtime();
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
    let future = rt.commands.call(rt.link.clone(), &command, args);
    async move {
        match rt.tokio.spawn(future).await {
            Ok(Ok(json)) => (true, json),
            Ok(Err(why)) => (false, why),
            Err(_) => (false, format!("{command} failed inside the app")),
        }
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
                    ToWindow::PlanetGone => me.planet_gone(),
                    ToWindow::Quit => me.quit_requested(),
                    ToWindow::Tray(up) => me.set_tray(up),
                    ToWindow::Event(name, data) => me
                        .as_mut()
                        .world_event(QString::from(&name), QString::from(&data)),
                    ToWindow::Open(path) => me.open_requested(QString::from(&path)),
                    ToWindow::Capture => me.capture_requested(),
                });
            }
        });
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

impl qobject::SolBackend {
    fn apply(mut self: Pin<&mut Self>, update: Update) {
        match update {
            Update::Status(status) => self.set_status(json(&status)),
            Update::Changed(collections) => {
                let n = *self.changes() + 1;
                self.as_mut().set_changes(n);
                self.changed(json(&collections));
            }
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
