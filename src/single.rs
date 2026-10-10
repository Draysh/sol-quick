//! One copy of each world at a time: a later copy asks the first to bring
//! its window up (or to open a page), and leaves. The door is a Unix socket
//! with an abstract name, one per person and world (a preview has its own):
//! the copy that binds it is the one that runs, and the name goes with that
//! process, so a crash leaves nothing behind. Another app can knock on it
//! too, to open a page here (`knock`).
//!
//! Versions before 1.0 used a socket file in the runtime directory
//! (`sol-<world>.sock`) instead. Until none is left, a copy also knocks there
//! before it runs (an older version running keeps the world), and listens
//! there, so an older version started later finds this one.

#[cfg(target_os = "linux")]
use std::{
    io::{BufRead, BufReader, ErrorKind, Read, Write},
    os::linux::net::SocketAddrExt,
    os::unix::net::{SocketAddr, UnixListener, UnixStream},
    path::PathBuf,
    sync::{Arc, OnceLock},
};

/// What a knock on the door asks for.
pub enum Knock {
    /// Bring the window up.
    Show,
    /// Bring it up at a page: `/title?key=x`.
    Open(String),
}

impl Knock {
    #[cfg(target_os = "linux")]
    fn line(&self) -> String {
        match self {
            Knock::Show => "show\n".into(),
            Knock::Open(path) => format!("open {}\n", path.replace('\n', " ")),
        }
    }
}

/// The socket file this copy listens on too; removed again when it leaves.
#[cfg(target_os = "linux")]
static OWNED: OnceLock<PathBuf> = OnceLock::new();

#[cfg(target_os = "linux")]
fn name(world: &str, preview: bool) -> String {
    if preview {
        format!("sol-preview-{world}")
    } else {
        format!("sol-{world}")
    }
}

#[cfg(target_os = "linux")]
fn runtime_dir() -> PathBuf {
    dirs::runtime_dir().unwrap_or_else(std::env::temp_dir)
}

/// The door: `sol-<world>:<runtime dir>`, abstract (no file).
#[cfg(target_os = "linux")]
fn address(world: &str, preview: bool) -> std::io::Result<SocketAddr> {
    let dir = runtime_dir();
    SocketAddr::from_abstract_name(format!("{}:{}", name(world, preview), dir.display()).as_bytes())
}

/// The door of versions before 1.0: `<runtime dir>/sol-<world>.sock`.
#[cfg(target_os = "linux")]
fn file(world: &str, preview: bool) -> PathBuf {
    runtime_dir().join(format!("{}.sock", name(world, preview)))
}

/// Asks the copy at the other end of `stream` for `knock` (`wait`: nothing,
/// a planet starting its moon again), and waits for its answer.
#[cfg(target_os = "linux")]
fn ask(mut stream: UnixStream, knock: Option<&Knock>) -> bool {
    let line = knock.map_or_else(|| "wait\n".to_owned(), |k| k.line());
    let mut ack = [0u8; 3];
    stream.write_all(line.as_bytes()).is_ok() && stream.read(&mut ack).is_ok_and(|n| n > 0)
}

/// Answers knocks on `listener`, each on this thread, until the app leaves.
#[cfg(target_os = "linux")]
fn serve(listener: UnixListener, on_knock: Arc<dyn Fn(Knock) + Send + Sync>) {
    let spawned = std::thread::Builder::new()
        .name("sol-single".into())
        .spawn(move || {
            for mut stream in listener.incoming().flatten() {
                let mut line = String::new();
                let _ = BufReader::new((&stream).take(4096)).read_line(&mut line);
                let line = line.trim_end();
                if line == "show" {
                    on_knock(Knock::Show);
                } else if let Some(path) = line.strip_prefix("open ") {
                    on_knock(Knock::Open(path.to_owned()));
                }
                let _ = stream.write_all(b"ok\n");
            }
        });
    if let Err(e) = spawned {
        tracing::warn!("no thread for the single-instance door: {e}");
    }
}

/// Claims the world for this copy. Returns false when another copy is
/// already running; it was asked for `knock` (a planet starting its moon
/// again passes None, and doesn't ask). Otherwise this copy holds the door,
/// and each later knock calls `on_knock`, on a thread of its own.
pub fn claim(
    world: &str,
    preview: bool,
    knock: Option<Knock>,
    on_knock: impl Fn(Knock) + Send + Sync + 'static,
) -> bool {
    #[cfg(target_os = "linux")]
    {
        let listener = match address(world, preview).and_then(|a| UnixListener::bind_addr(&a)) {
            Ok(listener) => listener,
            Err(e) if e.kind() == ErrorKind::AddrInUse => {
                if let Ok(stream) =
                    address(world, preview).and_then(|a| UnixStream::connect_addr(&a))
                {
                    ask(stream, knock.as_ref());
                }
                return false;
            }
            Err(e) => {
                tracing::warn!("no single-instance door ({e}); another copy could start");
                return true;
            }
        };
        // An older version of this app, running, knows only the file.
        let path = file(world, preview);
        if let Ok(stream) = UnixStream::connect(&path) {
            ask(stream, knock.as_ref());
            return false;
        }
        let on_knock: Arc<dyn Fn(Knock) + Send + Sync> = Arc::new(on_knock);
        serve(listener, on_knock.clone());
        // And an older version started later finds this one there.
        let _ = std::fs::remove_file(&path);
        match UnixListener::bind(&path) {
            Ok(old) => {
                let _ = OWNED.set(path);
                serve(old, on_knock);
            }
            Err(e) => tracing::debug!("no socket file for older versions: {e}"),
        }
        true
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = (world, preview, knock, on_knock);
        true
    }
}

/// Knocks on another world's door (its running copy); false when nobody
/// answers.
pub fn knock(world: &str, preview: bool, what: &Knock) -> bool {
    #[cfg(target_os = "linux")]
    {
        if let Ok(stream) = address(world, preview).and_then(|a| UnixStream::connect_addr(&a))
            && ask(stream, Some(what))
        {
            return true;
        }
        // A world still on a version before 1.0.
        UnixStream::connect(file(world, preview)).is_ok_and(|stream| ask(stream, Some(what)))
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = (world, preview, what);
        false
    }
}

/// Removes the socket file this copy listens on, if it has one.
pub fn leave() {
    #[cfg(target_os = "linux")]
    if let Some(path) = OWNED.get() {
        let _ = std::fs::remove_file(path);
    }
}

#[cfg(all(test, target_os = "linux"))]
mod tests {
    use std::sync::mpsc;

    use super::*;

    #[test]
    fn one_copy_holds_the_door_and_hears_knocks() {
        let world = format!("test-{}", std::process::id());
        let (tx, rx) = mpsc::channel();
        assert!(claim(&world, true, None, move |k| {
            let _ = tx.send(match k {
                Knock::Show => "show".to_owned(),
                Knock::Open(p) => p,
            });
        }));
        // A second copy finds it and asks for a page.
        assert!(!claim(&world, true, Some(Knock::Open("/x".into())), |_| {}));
        assert_eq!(rx.recv().unwrap(), "/x");
        // Through the socket file too, as an older version would.
        let stream = UnixStream::connect(file(&world, true)).unwrap();
        assert!(ask(stream, Some(&Knock::Show)));
        assert_eq!(rx.recv().unwrap(), "show");
        assert!(knock(&world, true, &Knock::Show));
        assert_eq!(rx.recv().unwrap(), "show");
        leave();
        assert!(!file(&world, true).exists());
    }

    #[test]
    fn an_older_version_running_keeps_the_world() {
        let world = format!("old-{}", std::process::id());
        // An older version: only the socket file.
        let path = file(&world, true);
        let _ = std::fs::remove_file(&path);
        let old = UnixListener::bind(&path).unwrap();
        let heard = std::thread::spawn(move || {
            let (mut stream, _) = old.accept().unwrap();
            let mut line = String::new();
            BufReader::new(&stream).read_line(&mut line).unwrap();
            stream.write_all(b"ok\n").unwrap();
            line
        });
        assert!(!claim(&world, true, Some(Knock::Show), |_| {}));
        assert_eq!(heard.join().unwrap(), "show\n");
        let _ = std::fs::remove_file(&path);
    }
}
