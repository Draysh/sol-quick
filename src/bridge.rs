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
        type SolBackend = super::Backend;

        /// Runs a command; the reply arrives as `replied(id, ok, body)`.
        #[qinvokable]
        fn call(self: Pin<&mut Self>, id: i32, command: &QString, args: &QString);

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

        /// A command's reply: the JSON it returned, or why it didn't.
        #[qsignal]
        fn replied(self: Pin<&mut Self>, id: i32, ok: bool, body: QString);

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
}

impl Default for Backend {
    fn default() -> Self {
        let rt = app::runtime();
        Self {
            world: QString::from(rt.link.world()),
            status: json(&rt.link.status()),
            unsent: 0,
            app: json(&rt.updates.status()),
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
                });
            }
        });
        // Subscribed before reading anything, so nothing between is missed.
        let mut updates = rt.link.subscribe();
        rt.tokio.spawn(async move {
            let link = &rt.link;
            let status = link.status();
            let app_status = rt.updates.status();
            let _ = qt.queue(move |mut me| {
                me.as_mut().set_status(json(&status));
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
        let command = command.to_string();
        let args = serde_json::from_str(&args.to_string()).unwrap_or(serde_json::Value::Null);
        let future = rt.commands.call(rt.link.clone(), &command, args);
        rt.tokio.spawn(async move {
            // A command that panics still answers, so the screen's promise settles.
            let (ok, body) = match rt.tokio.spawn(future).await {
                Ok(Ok(json)) => (true, json),
                Ok(Err(why)) => (false, why),
                Err(_) => (false, format!("{command} failed inside the app")),
            };
            let _ = qt.queue(move |me| me.replied(id, ok, QString::from(&body)));
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
}
