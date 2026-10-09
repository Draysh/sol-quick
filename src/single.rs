//! One copy of each world at a time: a later copy asks the first to bring
//! its window up (or to open a page), and leaves. The door is a Unix socket
//! in the runtime directory, named for the world (a preview has its own),
//! and the copy that binds it is the one that runs. Another app can knock
//! on it too, to open a page here (`knock`).

#[cfg(unix)]
use std::{
    io::{BufRead, BufReader, ErrorKind, Read, Write},
    os::unix::net::{UnixListener, UnixStream},
    path::PathBuf,
    sync::OnceLock,
};

/// What a knock on the door asks for.
pub enum Knock {
    /// Bring the window up.
    Show,
    /// Bring it up at a page: `/title?key=x`.
    Open(String),
}

impl Knock {
    #[cfg(unix)]
    fn line(&self) -> String {
        match self {
            Knock::Show => "show\n".into(),
            Knock::Open(path) => format!("open {}\n", path.replace('\n', " ")),
        }
    }
}

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
/// already running; it was asked for `knock` (a planet starting its moon
/// again passes None, and doesn't ask). Otherwise this copy holds the door,
/// and each later knock calls `on_knock`, on a thread of its own.
pub fn claim(
    world: &str,
    preview: bool,
    knock: Option<Knock>,
    on_knock: impl Fn(Knock) + Send + 'static,
) -> bool {
    #[cfg(unix)]
    {
        let path = socket(world, preview);
        let listener = match UnixListener::bind(&path) {
            Ok(listener) => listener,
            Err(e) if e.kind() == ErrorKind::AddrInUse => {
                if let Ok(mut stream) = UnixStream::connect(&path) {
                    let line = knock.map_or_else(|| "wait\n".to_owned(), |k| k.line());
                    let _ = stream.write_all(line.as_bytes());
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
        true
    }
    #[cfg(not(unix))]
    {
        let _ = (world, preview, knock, on_knock);
        true
    }
}

/// Knocks on another world's door (its running copy); false when nobody
/// answers.
pub fn knock(world: &str, preview: bool, what: &Knock) -> bool {
    #[cfg(unix)]
    {
        let Ok(mut stream) = UnixStream::connect(socket(world, preview)) else {
            return false;
        };
        let mut ack = [0u8; 3];
        stream.write_all(what.line().as_bytes()).is_ok()
            && stream.read(&mut ack).is_ok_and(|n| n > 0)
    }
    #[cfg(not(unix))]
    {
        let _ = (world, preview, what);
        false
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
