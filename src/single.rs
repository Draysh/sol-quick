//! One window per world: a second copy of the app asks the first to come
//! up and leaves. A Unix socket in the runtime directory, named for the
//! world, is the door.

use std::{
    io::{Read, Write},
    path::PathBuf,
};

#[cfg(unix)]
use std::os::unix::net::{UnixListener, UnixStream};

fn socket(world: &str) -> PathBuf {
    dirs::runtime_dir()
        .unwrap_or_else(std::env::temp_dir)
        .join(format!("sol-{world}.sock"))
}

/// Whether another copy is already running, which was told to show itself.
/// `show` asks it to bring its window up (a planet starting its moon again doesn't).
pub fn already_running(world: &str, show: bool) -> bool {
    #[cfg(unix)]
    {
        let path = socket(world);
        if let Ok(mut stream) = UnixStream::connect(&path) {
            let _ = stream.write_all(if show { b"show\n" } else { b"wait\n" });
            let mut ack = [0u8; 4];
            let _ = stream.read(&mut ack);
            return true;
        }
        // Nobody answers: a stale socket from a copy that crashed.
        let _ = std::fs::remove_file(&path);
    }
    false
}

/// Listens for later copies; `show` runs on a background thread each time
/// one knocks.
pub fn listen(world: &str, show: impl Fn() + Send + 'static) {
    #[cfg(unix)]
    {
        let path = socket(world);
        let Ok(listener) = UnixListener::bind(&path) else {
            tracing::warn!("no single-instance socket at {}", path.display());
            return;
        };
        std::thread::Builder::new()
            .name("sol-single".into())
            .spawn(move || {
                for stream in listener.incoming().flatten() {
                    let mut stream = stream;
                    let mut buf = [0u8; 8];
                    let n = stream.read(&mut buf).unwrap_or(0);
                    if buf[..n].starts_with(b"show") {
                        show();
                    }
                    let _ = stream.write_all(b"ok\n");
                }
            })
            .expect("a thread");
    }
    #[cfg(not(unix))]
    {
        let _ = (world, show);
    }
}

/// Removes the socket on a clean exit.
pub fn leave(world: &str) {
    let _ = std::fs::remove_file(socket(world));
}
