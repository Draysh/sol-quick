//! The desktop around the window: notifications that work with the window
//! hidden, and global shortcuts through the portal (the tray is `tray`).
//! Linux only for now: elsewhere there is no shortcut, and `notify` says it
//! can't. Both reach the screens as world events (`Sol.event`): `shortcut`
//! carries the id that was pressed, `notified` the action taken on a
//! notification.

use crate::app;

/// An entry in the tray's menu: its id (what the screens hear) and label.
pub type TrayItem = (&'static str, &'static str);
/// A global shortcut: id, what it does, and the keys to suggest (`CTRL+ALT+p`).
pub type Shortcut = (&'static str, &'static str, &'static str);

/// Shows a desktop notification. `action` is a button: its id comes back
/// as a `notified` event when it is pressed, or `default` when the
/// notification itself is. Waiting for that takes a thread of its own
/// until the notification is answered or closed.
pub async fn notify(
    title: &str,
    body: &str,
    action: Option<(String, String)>,
) -> Result<u32, String> {
    #[cfg(target_os = "linux")]
    {
        let rt = app::runtime();
        let mut n = notify_rust::Notification::new();
        n.appname(&rt.name)
            .summary(title)
            .body(body)
            .icon(&format!("sol-{}", rt.app.world));
        if let Some((id, label)) = &action {
            n.action(id, label);
            n.action("default", "Open");
        }
        let (tx, rx) = tokio::sync::oneshot::channel();
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
        rx.await.map_err(|e| e.to_string())?
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = (title, body, action);
        Err("notifications are Linux only for now".into())
    }
}

/// Binds the app's global shortcuts, once the runtime is up. Failures are
/// logged, never fatal: a desktop without the portal just doesn't get them.
pub fn start(shortcuts: &'static [Shortcut]) {
    #[cfg(target_os = "linux")]
    if !shortcuts.is_empty() {
        let shortcuts: Vec<Shortcut> = shortcuts.to_vec();
        app::runtime().tokio.spawn(async move {
            if let Err(e) = bind(&shortcuts).await {
                tracing::warn!("global shortcuts unavailable: {e}");
            }
        });
    }
    #[cfg(not(target_os = "linux"))]
    let _ = shortcuts;
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
