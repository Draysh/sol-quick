//! One copy of each world at a time: a later copy asks the first to bring
//! its window up, and leaves. The door is a Unix socket in the runtime
//! directory, named for the world (a preview has its own), and the copy
//! that binds it is the one that runs.

#[cfg(unix)]
use std::{
    io::{ErrorKind, Read, Write},
    os::unix::net::{UnixListener, UnixStream},
    path::PathBuf,
    sync::OnceLock,
};

/// The socket this copy bound; removed again when it leaves.
#[cfg(unix)]
static OWNED: OnceLock<PathBuf> = OnceLock::new();

#[cfg(unix)]
fn socket(world: &str, preview: bool) -> PathBuf {
    let name = if preview {
        format!("sol-preview-{world}.sock")
    } else {
        format!("sol-{world}.sock")
    };
    dirs::runtime_dir()
        .unwrap_or_else(std::env::temp_dir)
        .join(name)
}

/// Claims the world for this copy. Returns false when another copy is
/// already running; it was asked to bring its window up when `show` (a
/// planet starting its moon again doesn't ask). Otherwise this copy holds
/// the door, and each later copy that asks calls `on_show`, on a thread of
/// its own.
pub fn claim(world: &str, preview: bool, show: bool, on_show: impl Fn() + Send + 'static) -> bool {
    #[cfg(unix)]
    {
        let path = socket(world, preview);
        let listener = match UnixListener::bind(&path) {
            Ok(listener) => listener,
            Err(e) if e.kind() == ErrorKind::AddrInUse => {
                if let Ok(mut stream) = UnixStream::connect(&path) {
                    let _ = stream.write_all(if show { b"show\n" } else { b"wait\n" });
                    let mut ack = [0u8; 4];
                    let _ = stream.read(&mut ack);
                    return false;
                }
                // Nobody answers: the socket of a copy that crashed.
                let _ = std::fs::remove_file(&path);
                match UnixListener::bind(&path) {
                    Ok(listener) => listener,
                    Err(e) => return unguarded(&path, &e),
                }
            }
            Err(e) => return unguarded(&path, &e),
        };
        let _ = OWNED.set(path);
        let spawned = std::thread::Builder::new()
            .name("sol-single".into())
            .spawn(move || {
                for mut stream in listener.incoming().flatten() {
                    let mut buf = [0u8; 8];
                    let n = stream.read(&mut buf).unwrap_or(0);
                    if buf[..n].starts_with(b"show") {
                        on_show();
                    }
                    let _ = stream.write_all(b"ok\n");
                }
            });
        if let Err(e) = spawned {
            tracing::warn!("no thread for the single-instance door: {e}");
        }
        true
    }
    #[cfg(not(unix))]
    {
        let _ = (world, preview, show, on_show);
        true
    }
}

/// Runs without the door rather than not at all.
#[cfg(unix)]
fn unguarded(path: &std::path::Path, e: &std::io::Error) -> bool {
    tracing::warn!(
        "no single-instance socket at {} ({e}); another copy could start",
        path.display()
    );
    true
}

/// Removes the door this copy holds, if it holds one.
pub fn leave() {
    #[cfg(unix)]
    if let Some(path) = OWNED.get() {
        let _ = std::fs::remove_file(path);
    }
}
