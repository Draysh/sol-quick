//! The commands every world's screens can call besides its own: the
//! connection, doors to other apps, notifications, the app's own updates,
//! installing and restarting it, starting with the computer, a moon's
//! place beside its planet, and export and import of the world's own
//! collections.

use std::sync::Arc;

use orbit::{
    install::{self, App},
    link::Status,
    moons,
    world::Collection,
};

use crate::{
    app::{quit, runtime},
    autostart::{autostart, set_autostart},
    commands::{Commands, say},
    exchange, single,
};

/// The commands every world shares: the connection, the manifest, doors,
/// the app's own updates and installation, export and import.
pub(crate) fn add(
    commands: &mut Commands,
    app: App,
    parent: Option<String>,
    collections: Vec<Collection>,
) {
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
    struct Seq {
        seq: i64,
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
            // The new version runs from the next start (or a restart).
            let updates = &runtime().updates;
            updates.install().await.map_err(say)?;
            Ok(updates.status())
        })
        .add("set_auto_update", |_, a: Auto| async move {
            runtime().updates.set_auto(a.auto).await.map_err(say)
        })
        // Writes kept aside instead of sent: conflicts, rejected, earlier.
        .add("kept", |link, _: ()| async move {
            link.kept_writes().await.map_err(say)
        })
        .add("keep_mine", |link, a: Seq| async move {
            link.keep_mine(a.seq).await.map_err(say)
        })
        .add("drop_kept", |link, a: Seq| async move {
            link.drop_kept(a.seq).await.map_err(say)
        })
        .add("save_kept", |link, _: ()| async move {
            let json = link.export_kept().await.map_err(say)?;
            let dir = downloads()?;
            let path = dir.join(format!("sol-{}-kept-{}.json", link.world(), chrono_stamp()));
            let text = serde_json::to_string_pretty(&json).map_err(say)?;
            std::fs::write(&path, text).map_err(say)?;
            Ok(path.display().to_string())
        })
        // The local copy didn't open: it goes aside (kept), and the app
        // starts again from Sol's copy.
        .add("start_fresh", |_, _: ()| async move {
            let rt = runtime();
            if rt.problem.is_none() {
                return Err("the local copy is fine".to_string());
            }
            let aside = orbit::link::set_aside(&rt.data_dir, rt.link.world()).map_err(say)?;
            tracing::warn!(to = %aside.display(), "set the local copy aside; starting from Sol's");
            install::relaunch(&install::current_exe().map_err(say)?).map_err(say)?;
            quit();
            Ok(aside.display().to_string())
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

    // Everything in the world's own collections, as one file in Downloads.
    let kept = Arc::new(collections);
    let these = kept.clone();
    commands.add("export_world", move |link, _: ()| {
        let these = these.clone();
        async move {
            let dir = downloads()?;
            let (path, documents) = exchange::write(&link, &these, &dir, &chrono_stamp())
                .await
                .map_err(say)?;
            Ok(serde_json::json!({ "path": path.display().to_string(), "documents": documents }))
        }
    });
    // The desktop's file picker, for a file to open (null: closed): an
    // export to import, or another app's export for a world to read.
    #[derive(serde::Deserialize)]
    struct Filter {
        label: String,
        globs: Vec<String>,
    }
    #[derive(serde::Deserialize)]
    struct Pick {
        title: String,
        #[serde(default)]
        filter: Option<Filter>,
    }
    commands.add("pick_file", |_, a: Pick| async move {
        let folder = downloads().ok();
        let filter = a.filter.as_ref().map(|f| (f.label.as_str(), &f.globs[..]));
        crate::desktop::pick_file(&a.title, folder.as_deref(), filter).await
    });
    // An export file read back: with `dry`, what it would add and replace;
    // without, the same written through the link (merged by id, nothing deleted).
    #[derive(serde::Deserialize)]
    struct Import {
        path: String,
        #[serde(default)]
        dry: bool,
    }
    commands.add("import_world", move |link, a: Import| {
        let kept = kept.clone();
        async move {
            let path = a.path.strip_prefix("file://").unwrap_or(&a.path);
            let file = exchange::read(std::path::Path::new(path), link.world()).map_err(say)?;
            if a.dry {
                exchange::plan(&link, &kept, &file).await.map_err(say)
            } else {
                exchange::import(&link, &kept, &file).await.map_err(say)
            }
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

/// Where files the person saves go: Downloads, or home without one; a
/// preview keeps them in its own throwaway folder.
fn downloads() -> Result<std::path::PathBuf, String> {
    if runtime().preview {
        let dir = runtime().data_dir.join("downloads");
        std::fs::create_dir_all(&dir).map_err(say)?;
        return Ok(dir);
    }
    dirs::download_dir()
        .or_else(dirs::home_dir)
        .ok_or_else(|| "no folder to save into".to_string())
}

/// Now, for a file name: `2026-10-10-2014`.
fn chrono_stamp() -> String {
    chrono::Local::now().format("%Y-%m-%d-%H%M").to_string()
}
