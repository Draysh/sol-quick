//! The desktop around the window: a tray icon with a menu, notifications
//! that work with the window hidden, and global shortcuts through the
//! portal. Linux only; elsewhere each is a quiet no-op. Everything here
//! reaches the screens as world events (`Sol.event`): `tray` and
//! `shortcut` carry the id that was chosen, `notified` the action taken
//! on a notification.

use crate::app;

/// An entry in the tray's menu: its id (what the screens hear) and label.
pub type TrayItem = (&'static str, &'static str);
/// A global shortcut: id, what it does, and the keys to suggest (`CTRL+ALT+p`).
pub type Shortcut = (&'static str, &'static str, &'static str);

/// Shows a desktop notification. `action` is a button: its id comes back
/// as a `notified` event when it is pressed, or `default` when the
/// notification itself is.
pub fn notify(title: &str, body: &str, action: Option<(String, String)>) -> Result<u32, String> {
    #[cfg(target_os = "linux")]
    {
        let rt = app::runtime();
        let mut n = notify_rust::Notification::new();
        n.appname(rt.app.name)
            .summary(title)
            .body(body)
            .icon(&format!("sol-{}", rt.app.world));
        if let Some((id, label)) = &action {
            n.action(id, label);
            n.action("default", "Open");
        }
        let (tx, rx) = std::sync::mpsc::channel();
        std::thread::spawn(move || match n.show() {
            Ok(handle) => {
                let id = handle.id();
                let _ = tx.send(Ok(id));
                if action.is_some() {
                    handle.wait_for_action(|what| {
                        if what != "__closed" {
                            app::emit("notified", &serde_json::json!({ "id": id, "action": what }));
                        }
                    });
                }
            }
            Err(e) => {
                let _ = tx.send(Err(e.to_string()));
            }
        });
        rx.recv().map_err(|e| e.to_string())?
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = (title, body, action);
        Err("notifications are Linux only for now".into())
    }
}

/// Puts the app in the tray and binds its global shortcuts, once the
/// runtime is up. Failures are logged, never fatal: a desktop without a
/// tray or a portal just doesn't get them.
pub fn start(
    tray_items: &'static [TrayItem],
    shortcuts: &'static [Shortcut],
    icons: &'static [(u32, &'static [u8])],
) {
    #[cfg(target_os = "linux")]
    {
        let rt = app::runtime();
        if rt.background {
            return;
        }
        let items: Vec<TrayItem> = tray_items.to_vec();
        rt.tokio.spawn(async move {
            use ksni::TrayMethods;
            let tray = Tray {
                name: rt.app.name,
                world: rt.app.world,
                icons: icons
                    .iter()
                    .filter_map(|(size, png)| pixmap(*size, png))
                    .collect(),
                items,
            };
            match tray.spawn().await {
                Ok(handle) => {
                    // The handle keeps the tray alive for the life of the app.
                    std::mem::forget(handle);
                }
                Err(e) => tracing::warn!("no tray: {e}"),
            }
        });
        if !shortcuts.is_empty() {
            let shortcuts: Vec<Shortcut> = shortcuts.to_vec();
            rt.tokio.spawn(async move {
                if let Err(e) = bind(&shortcuts).await {
                    tracing::warn!("global shortcuts unavailable: {e}");
                }
            });
        }
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = (tray_items, shortcuts, icons);
    }
}

#[cfg(target_os = "linux")]
fn pixmap(size: u32, png: &[u8]) -> Option<ksni::Icon> {
    let img = image::load_from_memory(png).ok()?.to_rgba8();
    let mut data = Vec::with_capacity((size * size * 4) as usize);
    for px in img.pixels() {
        data.extend_from_slice(&[px[3], px[0], px[1], px[2]]);
    }
    Some(ksni::Icon {
        width: img.width() as i32,
        height: img.height() as i32,
        data,
    })
}

#[cfg(target_os = "linux")]
struct Tray {
    name: &'static str,
    world: &'static str,
    icons: Vec<ksni::Icon>,
    items: Vec<TrayItem>,
}

#[cfg(target_os = "linux")]
impl ksni::Tray for Tray {
    fn id(&self) -> String {
        format!("sol-{}", self.world)
    }
    fn title(&self) -> String {
        self.name.to_owned()
    }
    fn icon_pixmap(&self) -> Vec<ksni::Icon> {
        self.icons.clone()
    }
    /// A left click brings the window up.
    fn activate(&mut self, _x: i32, _y: i32) {
        app::runtime().activate_window();
    }
    fn menu(&self) -> Vec<ksni::MenuItem<Self>> {
        use ksni::menu::{MenuItem, StandardItem};
        let mut menu: Vec<MenuItem<Self>> = self
            .items
            .iter()
            .map(|(id, label)| {
                let id = *id;
                MenuItem::Standard(StandardItem {
                    label: (*label).to_owned(),
                    activate: Box::new(move |_: &mut Self| {
                        app::emit("tray", &serde_json::json!({ "id": id }));
                    }),
                    ..Default::default()
                })
            })
            .collect();
        if !menu.is_empty() {
            menu.push(MenuItem::Separator);
        }
        menu.push(MenuItem::Standard(StandardItem {
            label: format!("Open {}", self.name),
            activate: Box::new(|_: &mut Self| app::runtime().activate_window()),
            ..Default::default()
        }));
        menu.push(MenuItem::Standard(StandardItem {
            label: "Quit".into(),
            activate: Box::new(|_: &mut Self| app::leave(0)),
            ..Default::default()
        }));
        menu
    }
}

/// Binds the shortcuts through the GlobalShortcuts portal and passes each
/// press on as a `shortcut` event. The desktop may ask the person to
/// confirm the keys the first time.
#[cfg(target_os = "linux")]
async fn bind(shortcuts: &[Shortcut]) -> Result<(), String> {
    use ashpd::desktop::global_shortcuts::{GlobalShortcuts, NewShortcut};
    use futures_util::StreamExt;
    let portal = GlobalShortcuts::new().await.map_err(|e| e.to_string())?;
    let session = portal.create_session().await.map_err(|e| e.to_string())?;
    let wanted: Vec<NewShortcut> = shortcuts
        .iter()
        .map(|(id, what, keys)| NewShortcut::new(*id, *what).preferred_trigger(Some(*keys)))
        .collect();
    let request = portal
        .bind_shortcuts(&session, &wanted, None)
        .await
        .map_err(|e| e.to_string())?;
    let bound = request.response().map_err(|e| e.to_string())?;
    tracing::info!(
        "global shortcuts: {}",
        bound
            .shortcuts()
            .iter()
            .map(|s| format!("{} = {}", s.id(), s.trigger_description()))
            .collect::<Vec<_>>()
            .join(", ")
    );
    let mut presses = portal
        .receive_activated()
        .await
        .map_err(|e| e.to_string())?;
    while let Some(press) = presses.next().await {
        app::emit(
            "shortcut",
            &serde_json::json!({ "id": press.shortcut_id() }),
        );
    }
    Ok(())
}
