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
    commands::Commands,
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
            link.connect(&a.server).await
        })
        .add("cancel", |link, ()| async move {
            link.cancel();
            Ok(())
        })
        .add("forget", |link, ()| async move { link.forget().await })
        .add("settings", |link, ()| async move { link.settings().await })
        .add("open_in_sol", |link, ()| async move {
            let server = match link.status() {
                Status::Online { server, .. } | Status::Offline { server, .. } => server,
                _ => anyhow::bail!("pair with Sol first"),
            };
            Ok(open::that_detached(format!(
                "{server}/worlds/{}",
                link.world()
            ))?)
        })
        .add(
            "doors",
            |_, ()| async move { Ok(orbit::doors::installed()) },
        )
        .add("open_world", |_, a: Which| async move {
            let Some(path) = a.path else {
                return orbit::doors::open(&a.world);
            };
            // Running: it opens the page. If not, it starts, and opens it once it answers.
            let knock = single::Knock::Open(path);
            let preview = runtime().preview;
            if single::knock(&a.world, preview, &knock) {
                return Ok(());
            }
            orbit::doors::open(&a.world)?;
            for _ in 0..40 {
                tokio::time::sleep(std::time::Duration::from_millis(250)).await;
                if single::knock(&a.world, preview, &knock) {
                    return Ok(());
                }
            }
            anyhow::bail!("{} started, but didn't open the page", a.world)
        })
        .add("check_updates", |_, ()| async move {
            let updates = &runtime().updates;
            updates.check().await?;
            Ok(updates.status())
        })
        .add("install_update", |_, ()| async move {
            // The new version runs from the next start (or a restart).
            let updates = &runtime().updates;
            updates.install().await?;
            Ok(updates.status())
        })
        .add("set_auto_update", |_, a: Auto| async move {
            runtime().updates.set_auto(a.auto).await
        })
        // Writes kept aside instead of sent: conflicts, rejected, earlier.
        .add("kept", |link, ()| async move { link.kept_writes().await })
        .add("keep_mine", |link, a: Seq| async move {
            link.keep_mine(a.seq).await
        })
        .add("drop_kept", |link, a: Seq| async move {
            link.drop_kept(a.seq).await
        })
        .add("save_kept", |link, ()| async move {
            let json = link.export_kept().await?;
            let dir = downloads()?;
            let path = dir.join(format!("sol-{}-kept-{}.json", link.world(), chrono_stamp()));
            let text = serde_json::to_string_pretty(&json)?;
            std::fs::write(&path, text)?;
            Ok(path.display().to_string())
        })
        // The local copy didn't open: it goes aside (kept), and the app
        // starts again from Sol's copy.
        .add("start_fresh", |_, ()| async move {
            let rt = runtime();
            if rt.problem.is_none() {
                anyhow::bail!("the local copy is fine");
            }
            let aside = orbit::link::set_aside(&rt.data_dir, rt.link.world())?;
            tracing::warn!(to = %aside.display(), "set the local copy aside; starting from Sol's");
            install::relaunch(&install::current_exe()?)?;
            quit();
            Ok(aside.display().to_string())
        });

    // Both start the installed copy, which waits for this one to leave.
    commands.add("restart", move |_, ()| async move {
        let path = match install::here(&app) {
            install::Here::Installed { path, .. } | install::Here::Loose { path } => path,
            _ => anyhow::bail!("start the app again yourself"),
        };
        install::relaunch(&path)?;
        quit();
        Ok(())
    });
    // Starting with the computer, in the tray without a window: only the
    // installed copy can (null otherwise).
    commands.add("autostart", move |_, ()| async move { Ok(autostart(&app)) });
    commands.add("set_autostart", move |_, a: On| async move {
        set_autostart(&app, a.on).map_err(anyhow::Error::msg)?;
        Ok(autostart(&app))
    });
    commands.add("install_app", move |_, ()| async move {
        let bin = install::install(&app)?;
        install::relaunch(&bin)?;
        quit();
        anyhow::Ok(())
    });

    // Everything in the world's own collections, as one file in Downloads.
    let kept_ids: Vec<String> = collections.iter().map(|c| c.id.clone()).collect();
    let kept = Arc::new(collections);
    let these = kept.clone();
    commands.add("export_world", move |link, ()| {
        let these = these.clone();
        async move {
            let dir = downloads()?;
            let (path, documents) = exchange::write(&link, &these, &dir, &chrono_stamp()).await?;
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
            let file = exchange::read(std::path::Path::new(path), link.world())?;
            if a.dry {
                exchange::plan(&link, &kept, &file).await
            } else {
                exchange::import(&link, &kept, &file).await
            }
        }
    });

    // Moments: whether an occasion is new to the person (recorded the
    // first time, so no device plays it again).
    #[derive(serde::Deserialize)]
    struct Occasion {
        occasion: String,
    }
    commands.add("moment", |link, a: Occasion| async move {
        crate::moments::first_time(&link, &a.occasion, &crate::app::device_name()).await
    });
    // Undo: the documents an undoable write changed (the `undoable` call
    // keeps them under a token), put back as they were.
    #[derive(serde::Deserialize)]
    struct Restore {
        undo: u64,
    }
    let own: Arc<Vec<String>> = Arc::new(
        kept_ids
            .iter()
            .cloned()
            .chain([crate::moments::MOMENTS.to_owned()])
            .collect(),
    );
    commands.add("restore", move |link, a: Restore| {
        let own = own.clone();
        async move {
            let before = crate::undo::take(a.undo)
                .ok_or_else(|| anyhow::anyhow!("that is too long ago to take back"))?;
            crate::undo::restore(&link, &before, &own).await
        }
    });
    // Quick capture: what each running world would do with a line, and doing it.
    #[derive(serde::Deserialize)]
    struct Capture {
        line: String,
        #[serde(default)]
        world: Option<String>,
    }
    commands.add("capture", |_, a: Capture| async move {
        match a.world {
            Some(world) => crate::capture::run(&world, &a.line)
                .await
                .map(serde_json::Value::String)
                .map_err(anyhow::Error::msg),
            None => Ok(serde_json::json!(crate::capture::offers(&a.line).await)),
        }
    });

    // A moon's place beside its planet: running with it, without a window.
    if let Some(parent) = parent {
        let (me, p) = (app, parent.clone());
        commands.add("with_planet", move |_, ()| {
            let (me, p) = (me, p.clone());
            async move { Ok(moons::enabled(&me, &p)) }
        });
        let (me, p) = (app, parent);
        commands.add("set_with_planet", move |_, a: On| {
            let (me, p) = (me, p.clone());
            async move {
                moons::set_enabled(&me, &p, a.on)?;
                Ok(moons::enabled(&me, &p))
            }
        });
    }
}

/// Where files the person saves go: Downloads, or home without one; a
/// preview keeps them in its own throwaway folder.
fn downloads() -> anyhow::Result<std::path::PathBuf> {
    if runtime().preview {
        let dir = runtime().data_dir.join("downloads");
        std::fs::create_dir_all(&dir)?;
        return Ok(dir);
    }
    dirs::download_dir()
        .or_else(dirs::home_dir)
        .ok_or_else(|| anyhow::anyhow!("no folder to save into"))
}

/// Now, for a file name: `2026-10-10-2014`.
fn chrono_stamp() -> String {
    chrono::Local::now().format("%Y-%m-%d-%H%M").to_string()
}
