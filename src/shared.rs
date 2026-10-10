//! The commands every world's screens can call besides its own: the
//! connection, doors to other apps, notifications, the app's own updates,
//! installing and restarting it, starting with the computer, and a moon's
//! place beside its planet.

use orbit::{
    install::{self, App},
    link::Status,
    moons,
    updates::Next,
};

use crate::{
    app::{quit, runtime},
    autostart::{autostart, set_autostart},
    commands::{Commands, say},
    single,
};

/// The commands every world shares: the connection, the manifest, doors,
/// the app's own updates and installation.
pub(crate) fn add(commands: &mut Commands, app: App, parent: Option<String>) {
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
