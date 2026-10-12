//! The commands every world's screens can call besides its own, by area:
//! the connection (and the writes kept aside), doors to other apps and
//! notifications, the app itself (updates, installing, restarting, starting
//! with the computer), export and import of the world's own collections,
//! moments and the sky, undo, and quick capture.

use std::sync::Arc;

use orbit::{
    install::{self, App},
    link::Status,
    world::Collection,
};

use crate::{
    app::{quit, runtime},
    autostart::{autostart, set_autostart},
    commands::Commands,
    exchange, single,
};

/// The commands every world shares: the connection, the manifest, doors,
/// the app's own updates and installation, export and import, moments and
/// the sky, undo and quick capture.
#[doc(hidden)]
pub fn add(commands: &mut Commands, app: App, collections: Vec<Collection>) {
    connection(commands);
    desktop(commands);
    the_app(commands, app);
    undo(commands, &collections);
    export_and_import(commands, collections);
    moments_and_sky(commands, app);
    capture(commands);
}

/// Pairing with Sol, its settings, the world's page there, the writes kept
/// aside instead of sent, and starting again from Sol's copy.
fn connection(commands: &mut Commands) {
    #[derive(serde::Deserialize)]
    struct Server {
        server: String,
    }
    #[derive(serde::Deserialize)]
    struct Seq {
        seq: i64,
    }
    commands
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
}

/// The desktop around the app: notifications, the other apps installed
/// here and opening one (at a page), and the file picker.
fn desktop(commands: &mut Commands) {
    #[derive(serde::Deserialize)]
    struct Notify {
        title: String,
        #[serde(default)]
        body: String,
        /// A button, as `[id, label]`; pressing it is a `notified` event.
        action: Option<(String, String)>,
    }
    #[derive(serde::Deserialize)]
    struct Which {
        world: String,
        /// A page there: `/title?key=x`.
        #[serde(default)]
        path: Option<String>,
    }
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
    commands
        .add("notify", |_, a: Notify| async move {
            crate::desktop::notify(&a.title, &a.body, a.action).await
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
        .add("pick_file", |_, a: Pick| async move {
            let folder = downloads().ok();
            let filter = a.filter.as_ref().map(|f| (f.label.as_str(), &f.globs[..]));
            crate::desktop::pick_file(&a.title, folder.as_deref(), filter).await
        });
}

/// The app itself: its updates, installing it, starting it again, and
/// starting with the computer.
fn the_app(commands: &mut Commands, app: App) {
    #[derive(serde::Deserialize)]
    struct Auto {
        auto: bool,
    }
    #[derive(serde::Deserialize)]
    struct On {
        on: bool,
    }
    commands
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
    commands.add("install_app", move |_, ()| async move {
        let bin = install::install(&app)?;
        install::relaunch(&bin)?;
        quit();
        anyhow::Ok(())
    });
    // Starting with the computer, in the tray without a window: only the
    // installed copy can (null otherwise).
    commands.add("autostart", move |_, ()| async move { Ok(autostart(&app)) });
    commands.add("set_autostart", move |_, a: On| async move {
        set_autostart(&app, a.on).map_err(anyhow::Error::msg)?;
        Ok(autostart(&app))
    });
}

/// Everything in the world's own collections as one file in Downloads, and
/// such a file read back: with `dry`, what it would add and replace;
/// without, the same written through the link (merged by id, nothing
/// deleted).
fn export_and_import(commands: &mut Commands, collections: Vec<Collection>) {
    #[derive(serde::Deserialize)]
    struct Import {
        path: String,
        #[serde(default)]
        dry: bool,
    }
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
}

/// Moments: whether an occasion is new to the person (recorded the first
/// time, so no device plays it again). The sky: today's comet (its day, or
/// null), catching it, and what the real sky has tonight for this world
/// (each lit as a star the first time).
fn moments_and_sky(commands: &mut Commands, app: App) {
    #[derive(serde::Deserialize)]
    struct Occasion {
        occasion: String,
    }
    #[derive(serde::Deserialize)]
    struct Day {
        day: chrono::NaiveDate,
    }
    commands.add("moment", |link, a: Occasion| async move {
        crate::moments::first_time(&link, &a.occasion, &crate::app::device_name()).await
    });
    commands.add("comet", |link, ()| async move {
        let today = orbit::clock::Clock::calendar(&link).today();
        crate::sky::comet(&link, today).await
    });
    let name = app.name;
    commands.add("catch_comet", move |link, a: Day| async move {
        let lit = crate::sky::catch_comet(&link, a.day, name).await?;
        crate::emit_in(link.world(), "sky.lit", &lit);
        Ok(lit)
    });
    commands.add("sky_tonight", |link, ()| async move {
        crate::sky::tonight(&link).await
    });
}

/// Undo: the documents an undoable write changed (the `undoable` call keeps
/// them under a token), put back as they were, in the world's own
/// collections and the kit's moments and sky.
fn undo(commands: &mut Commands, collections: &[Collection]) {
    #[derive(serde::Deserialize)]
    struct Restore {
        undo: u64,
    }
    let own: Arc<Vec<String>> = Arc::new(
        collections
            .iter()
            .map(|c| c.id.clone())
            .chain([
                crate::moments::MOMENTS.to_owned(),
                crate::sky::SKY.to_owned(),
            ])
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
}

/// Quick capture: what each running world would do with a line, and doing it.
fn capture(commands: &mut Commands) {
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
