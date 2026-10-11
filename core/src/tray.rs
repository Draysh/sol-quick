//! One Sol icon in the tray for every Sol app running on this computer.
//!
//! The first app to start hosts it; the others register with the host over
//! a Unix socket and keep their entries there, and when the host quits the
//! next one takes over (the socket has an abstract name, so it goes with
//! the process that held it: nothing is left behind to clean up). Each app
//! has a submenu: Open, its own entries (`World::tray`), Quit. A count an
//! app sets (`Sol.badge`: cards due, habits left) shows beside its name, in
//! the tooltip, and on its icon in docks that read the Launcher Entry API.
//! A choice reaches the app's screens as a `tray` event.

use serde::{Deserialize, Serialize};

use crate::desktop::TrayItem;

/// What an app counts, for the tray and its icon.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Badge {
    pub count: u32,
    pub what: String,
}

/// An app in the tray: who it is, its own entries, and its count.
#[derive(Clone, Debug, Serialize, Deserialize)]
struct Member {
    world: String,
    name: String,
    role: String,
    items: Vec<(String, String)>,
    badge: Badge,
}

/// From an app to the host.
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
enum Up {
    Hello(Member),
    Badge(Badge),
}

/// From the host to an app.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
enum Down {
    Open,
    Quit,
    Item(String),
    /// Whether there is a tray to come back from, so closing may hide.
    Tray(bool),
}

/// This app's count; the tray (as host or member) follows it.
static BADGE: std::sync::OnceLock<tokio::sync::watch::Sender<Badge>> = std::sync::OnceLock::new();

fn badge_channel() -> &'static tokio::sync::watch::Sender<Badge> {
    BADGE.get_or_init(|| tokio::sync::watch::channel(Badge::default()).0)
}

/// Sets this app's count (0 clears it).
pub fn badge(count: u32, what: &str) {
    let badge = Badge {
        count,
        what: what.to_owned(),
    };
    let changed = badge_channel().send_if_modified(|now| {
        let changed = *now != badge;
        *now = badge.clone();
        changed
    });
    #[cfg(target_os = "linux")]
    if changed {
        let world = crate::app::runtime().app.world;
        crate::app::runtime().tokio.spawn(async move {
            if let Err(e) = linux::launcher_count(world, count).await {
                tracing::debug!("no launcher count: {e}");
            }
        });
    }
    #[cfg(not(target_os = "linux"))]
    let _ = changed;
}

/// Joins the Sol tray (hosting it if no other app does). Never fatal: a
/// desktop without a tray just doesn't get one.
pub fn start(items: &'static [TrayItem]) {
    #[cfg(target_os = "linux")]
    {
        let rt = crate::app::runtime();
        let me = Member {
            world: rt.app.world.to_owned(),
            name: rt.name.clone(),
            role: rt.role.clone(),
            items: items
                .iter()
                .map(|(id, label)| ((*id).to_owned(), (*label).to_owned()))
                .collect(),
            badge: badge_channel().borrow().clone(),
        };
        rt.tokio.spawn(linux::run(me));
    }
    #[cfg(not(target_os = "linux"))]
    let _ = items;
}

#[cfg(target_os = "linux")]
mod linux {
    use std::os::linux::net::SocketAddrExt;
    use std::os::unix::net::{SocketAddr, UnixListener as StdListener, UnixStream as StdStream};
    use std::time::Duration;

    use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
    use tokio::net::{UnixListener, UnixStream};
    use tokio::sync::{mpsc, watch};

    use super::{Badge, Down, Member, Up};
    use crate::app;

    /// The socket's abstract name: one per user (their runtime directory).
    fn address() -> std::io::Result<SocketAddr> {
        let dir = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
        SocketAddr::from_abstract_name(format!("sol-tray:{dir}").as_bytes())
    }

    /// Hosts the tray, or joins whoever does; when the host goes, tries again.
    pub(super) async fn run(me: Member) {
        let mine = super::badge_channel().subscribe();
        for attempt in 0u64.. {
            let addr = match address() {
                Ok(addr) => addr,
                Err(e) => return tracing::warn!("no tray socket: {e}"),
            };
            match StdListener::bind_addr(&addr) {
                Ok(listener) => {
                    let listener = listener
                        .set_nonblocking(true)
                        .and_then(|()| UnixListener::from_std(listener));
                    match listener {
                        Ok(listener) => return host(listener, me, mine).await,
                        Err(e) => return tracing::warn!("no tray socket: {e}"),
                    }
                }
                Err(e) if e.kind() == std::io::ErrorKind::AddrInUse => {
                    let stream = StdStream::connect_addr(&addr).and_then(|s| {
                        s.set_nonblocking(true)?;
                        UnixStream::from_std(s)
                    });
                    if let Ok(stream) = stream {
                        member(stream, me.clone(), mine.clone()).await;
                    }
                    // The host went: one of those left takes over, a moment apart.
                    let jitter = u64::from(std::process::id() % 200) + 50 * (attempt % 4);
                    tokio::time::sleep(Duration::from_millis(jitter)).await;
                }
                Err(e) => return tracing::warn!("no tray socket: {e}"),
            }
        }
    }

    /// An app that joined: follows the host's word, tells it its count.
    async fn member(stream: UnixStream, mut me: Member, mut mine: watch::Receiver<Badge>) {
        let rt = app::runtime();
        let (read, mut write) = stream.into_split();
        me.badge = mine.borrow_and_update().clone();
        if send(&mut write, &Up::Hello(me)).await.is_err() {
            return;
        }
        let mut lines = BufReader::new(read).lines();
        loop {
            tokio::select! {
                line = lines.next_line() => match line {
                    Ok(Some(line)) => match serde_json::from_str::<Down>(&line) {
                        Ok(Down::Open) => rt.activate_window(),
                        Ok(Down::Quit) => app::quit(),
                        Ok(Down::Item(id)) => app::emit("tray", &serde_json::json!({ "id": id })),
                        Ok(Down::Tray(up)) => rt.set_tray(up),
                        Err(e) => tracing::warn!("the tray said something odd: {e}"),
                    },
                    _ => break,
                },
                changed = mine.changed() => {
                    if changed.is_err() { break }
                    let badge = mine.borrow_and_update().clone();
                    if send(&mut write, &Up::Badge(badge)).await.is_err() { break }
                }
            }
        }
        // No host for a moment: closing the window would lose the app.
        rt.set_tray(false);
    }

    async fn send<T: serde::Serialize>(
        write: &mut tokio::net::unix::OwnedWriteHalf,
        what: &T,
    ) -> std::io::Result<()> {
        let mut line = serde_json::to_string(what).map_err(std::io::Error::other)?;
        line.push('\n');
        write.write_all(line.as_bytes()).await
    }

    /// An app in the host's menu; `to` is how to reach it (None: the host itself).
    struct Entry {
        id: u64,
        member: Member,
        to: Option<mpsc::UnboundedSender<Down>>,
    }

    struct SolTray {
        entries: Vec<Entry>,
        icon: Vec<ksni::Icon>,
        up: bool,
    }

    impl SolTray {
        /// Does `what` for the app `id`: here, or through its socket.
        fn tell(&self, id: u64, what: Down) {
            let Some(entry) = self.entries.iter().find(|e| e.id == id) else {
                return;
            };
            match &entry.to {
                Some(to) => {
                    let _ = to.send(what);
                }
                None => match what {
                    Down::Open => app::runtime().activate_window(),
                    Down::Quit => app::quit(),
                    Down::Item(item) => app::emit("tray", &serde_json::json!({ "id": item })),
                    Down::Tray(_) => {}
                },
            }
        }
        fn set_up(&mut self, up: bool) {
            self.up = up;
            self.tell_all(up);
        }
        fn tell_all(&self, up: bool) {
            app::runtime().set_tray(up);
            for entry in &self.entries {
                if let Some(to) = &entry.to {
                    let _ = to.send(Down::Tray(up));
                }
            }
        }
    }

    fn counted(badge: &Badge) -> String {
        match badge.count {
            0 => String::new(),
            n if badge.what.is_empty() => format!(" · {n}"),
            n => format!(" · {n} {}", badge.what),
        }
    }

    impl ksni::Tray for SolTray {
        const MENU_ON_ACTIVATE: bool = true;
        fn id(&self) -> String {
            "sol".into()
        }
        fn title(&self) -> String {
            "Sol".into()
        }
        fn icon_pixmap(&self) -> Vec<ksni::Icon> {
            self.icon.clone()
        }
        fn tool_tip(&self) -> ksni::ToolTip {
            ksni::ToolTip {
                title: "Sol".into(),
                description: self
                    .entries
                    .iter()
                    .map(|e| format!("{}{}", e.member.name, counted(&e.member.badge)))
                    .collect::<Vec<_>>()
                    .join("\n"),
                ..Default::default()
            }
        }
        /// The panel's tray went away (or came back): closing a window hides
        /// it only while there is a tray to come back from, in every app.
        fn watcher_offline(&self, _reason: ksni::OfflineReason) -> bool {
            self.tell_all(false);
            true
        }
        fn watcher_online(&self) {
            self.tell_all(true);
        }
        fn menu(&self) -> Vec<ksni::MenuItem<Self>> {
            use ksni::menu::{MenuItem, StandardItem, SubMenu};
            let item = |label: String, id: u64, what: Down| {
                MenuItem::Standard(StandardItem {
                    label,
                    activate: Box::new(move |tray: &mut Self| tray.tell(id, what.clone())),
                    ..Default::default()
                })
            };
            let mut menu: Vec<MenuItem<Self>> = self
                .entries
                .iter()
                .map(|e| {
                    let m = &e.member;
                    let mut submenu = vec![item(format!("Open {}", m.name), e.id, Down::Open)];
                    for (id, label) in &m.items {
                        submenu.push(item(label.clone(), e.id, Down::Item(id.clone())));
                    }
                    submenu.push(MenuItem::Separator);
                    submenu.push(item(format!("Quit {}", m.name), e.id, Down::Quit));
                    let role = if m.role.is_empty() {
                        String::new()
                    } else {
                        format!(" · {}", m.role)
                    };
                    MenuItem::SubMenu(SubMenu {
                        label: format!("{}{role}{}", m.name, counted(&m.badge)),
                        submenu,
                        ..Default::default()
                    })
                })
                .collect();
            menu.push(MenuItem::Separator);
            menu.push(MenuItem::Standard(StandardItem {
                label: "Quit every Sol app".into(),
                activate: Box::new(|tray: &mut Self| {
                    for e in &tray.entries {
                        if let Some(to) = &e.to {
                            let _ = to.send(Down::Quit);
                        }
                    }
                    app::quit();
                }),
                ..Default::default()
            }));
            menu
        }
    }

    /// The host: the icon, and a registry of the apps that joined.
    async fn host(listener: UnixListener, me: Member, mut mine: watch::Receiver<Badge>) {
        use ksni::TrayMethods;
        let tray = SolTray {
            entries: vec![Entry {
                id: 0,
                member: me,
                to: None,
            }],
            icon: pixmap(include_bytes!("../../assets/sol-tray.png"))
                .into_iter()
                .collect(),
            up: false,
        };
        let handle = match tray.spawn().await {
            Ok(handle) => handle,
            Err(e) => {
                // No tray on this desktop: nobody gets one, so closing quits.
                tracing::warn!("no tray: {e}");
                return;
            }
        };
        handle.update(|t| t.set_up(true)).await;
        let mut next = 1u64;
        loop {
            tokio::select! {
                accepted = listener.accept() => {
                    let Ok((stream, _)) = accepted else { continue };
                    tokio::spawn(serve(stream, next, handle.clone()));
                    next += 1;
                }
                changed = mine.changed() => {
                    if changed.is_err() { break }
                    let badge = mine.borrow_and_update().clone();
                    handle.update(move |t| if let Some(e) = t.entries.iter_mut().find(|e| e.id == 0) { e.member.badge = badge }).await;
                }
            }
        }
    }

    /// One app that joined, for as long as it stays.
    async fn serve(stream: UnixStream, id: u64, handle: ksni::Handle<SolTray>) {
        let (read, mut write) = stream.into_split();
        let (to, mut queue) = mpsc::unbounded_channel::<Down>();
        tokio::spawn(async move {
            while let Some(what) = queue.recv().await {
                if send(&mut write, &what).await.is_err() {
                    break;
                }
            }
        });
        let mut lines = BufReader::new(read).lines();
        while let Ok(Some(line)) = lines.next_line().await {
            match serde_json::from_str::<Up>(&line) {
                Ok(Up::Hello(member)) => {
                    let to = to.clone();
                    handle
                        .update(move |t| {
                            let _ = to.send(Down::Tray(t.up));
                            t.entries.retain(|e| e.id != id);
                            t.entries.push(Entry {
                                id,
                                member,
                                to: Some(to),
                            });
                        })
                        .await;
                }
                Ok(Up::Badge(badge)) => {
                    handle
                        .update(move |t| {
                            if let Some(e) = t.entries.iter_mut().find(|e| e.id == id) {
                                e.member.badge = badge;
                            }
                        })
                        .await;
                }
                Err(e) => tracing::warn!("an app told the tray something odd: {e}"),
            }
        }
        handle
            .update(move |t| t.entries.retain(|e| e.id != id))
            .await;
    }

    pub(super) fn pixmap(png: &[u8]) -> Option<ksni::Icon> {
        let img = image::load_from_memory(png).ok()?.to_rgba8();
        let mut data = Vec::with_capacity((img.width() * img.height() * 4) as usize);
        for px in img.pixels() {
            data.extend_from_slice(&[px[3], px[0], px[1], px[2]]);
        }
        Some(ksni::Icon {
            width: img.width() as i32,
            height: img.height() as i32,
            data,
        })
    }

    /// The count on the app's icon, for docks that read the Launcher Entry API.
    pub(super) async fn launcher_count(world: &str, count: u32) -> zbus::Result<()> {
        use std::collections::HashMap;
        use zbus::zvariant::Value;
        static BUS: tokio::sync::OnceCell<zbus::Connection> = tokio::sync::OnceCell::const_new();
        let bus = BUS.get_or_try_init(zbus::Connection::session).await?;
        let mut props: HashMap<&str, Value> = HashMap::new();
        props.insert("count", Value::I64(i64::from(count)));
        props.insert("count-visible", Value::Bool(count > 0));
        let path = format!(
            "/com/canonical/unity/launcherentry/sol_{}",
            world.replace('-', "_")
        );
        bus.emit_signal(
            None::<()>,
            path.as_str(),
            "com.canonical.Unity.LauncherEntry",
            "Update",
            &(format!("application://sol-{world}.desktop"), props),
        )
        .await
    }
}
