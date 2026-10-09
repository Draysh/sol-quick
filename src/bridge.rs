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

use cxx_qt::Threading;
use cxx_qt_lib::QString;
use orbit::link::Update;

use crate::app::{self, Runtime};

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
            tray: rt.tray,
            fps: std::env::var_os("SOL_FPS").is_some(),
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
        rt.set_activate({
            let qt = qt.clone();
            move || {
                let _ = qt.queue(|me| me.activate());
            }
        });
        rt.set_planet_gone({
            let qt = qt.clone();
            move || {
                let _ = qt.queue(|me| me.planet_gone());
            }
        });
        rt.set_emit({
            let qt = qt.clone();
            move |name: String, data: String| {
                let _ =
                    qt.queue(move |me| me.world_event(QString::from(&name), QString::from(&data)));
            }
        });
        let link = rt.link.clone();
        rt.tokio.spawn(async move {
            let mut updates = link.subscribe();
            while let Ok(update) = updates.recv().await {
                let unsent = link.unsent().await.unwrap_or(0) as i32;
                let _ = qt.queue(move |mut me| {
                    me.as_mut().set_unsent(unsent);
                    me.apply(update);
                });
            }
        });
        let qt = self.qt_thread();
        rt.tokio.spawn(async move {
            let unsent = rt.link.unsent().await.unwrap_or(0) as i32;
            let _ = qt.queue(move |me| me.set_unsent(unsent));
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
            let (ok, body) = match future.await {
                Ok(value) => (true, value.to_string()),
                Err(why) => (false, why),
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
