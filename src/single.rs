//! One copy of each world at a time: a later copy asks the first to bring
//! its window up (or to open a page), and leaves. The door is a Unix socket
//! with an abstract name, one per person and world (a preview has its own):
//! the copy that binds it is the one that runs, and the name goes with that
//! process, so a crash leaves nothing behind. Another app can knock on it
//! too, to open a page here (`knock`), or the desktop, to have something
//! done or found (`ask`: `--do`, `--find`, answered by the world's own
//! `do` and `find` commands).
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
    /// Run one of the world's door commands (`do`, `find`, `ask`) with these
    /// arguments, and answer with its reply. The window stays as it is.
    Ask(String, serde_json::Value),
}

/// How an `ask` went.
pub enum Asked {
    /// The command's reply, as JSON text.
    Yes(String),
    /// Why it couldn't, in one sentence.
    No(String),
    /// A copy older than asking runs (it answered only "ok").
    Old,
    /// No copy runs.
    Nobody,
}

impl Knock {
    #[cfg(target_os = "linux")]
    fn line(&self) -> String {
        match self {
            Knock::Show => "show\n".into(),
            Knock::Open(path) => format!("open {}\n", path.replace('\n', " ")),
            Knock::Ask(command, args) => format!("ask {command} {args}\n"),
        }
    }
}

/// The socket file this copy listens on too; removed again when it leaves.
#[cfg(target_os = "linux")]
static OWNED: OnceLock<PathBuf> = OnceLock::new();

#[cfg(target_os = "linux")]
fn name(world: &str, preview: bool) -> String {
    // A test's doors are its own, so nothing reaches an app running here.
    #[cfg(feature = "testing")]
    {
        let _ = preview;
        format!("sol-test-{}-{world}", std::process::id())
    }
    #[cfg(not(feature = "testing"))]
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
fn knock_on(mut stream: UnixStream, knock: Option<&Knock>) -> bool {
    let line = knock.map_or_else(|| "wait\n".to_owned(), |k| k.line());
    let mut ack = [0u8; 3];
    stream.write_all(line.as_bytes()).is_ok() && stream.read(&mut ack).is_ok_and(|n| n > 0)
}

/// What a copy says back to a knock: `ok`, or for an ask `ok <reply>` /
/// `no <why>`.
pub type Answer = Option<Result<String, String>>;

/// Reads one knock and answers it.
#[cfg(target_os = "linux")]
fn answer(mut stream: UnixStream, on_knock: &(dyn Fn(Knock) -> Answer + Send + Sync)) {
    let mut line = String::new();
    let _ = BufReader::new((&stream).take(64 * 1024)).read_line(&mut line);
    let line = line.trim_end();
    let knock = if line == "show" {
        Some(Knock::Show)
    } else if let Some(path) = line.strip_prefix("open ") {
        Some(Knock::Open(path.to_owned()))
    } else if let Some(rest) = line.strip_prefix("ask ") {
        let (command, args) = rest.split_once(' ').unwrap_or((rest, "null"));
        Some(Knock::Ask(
            command.to_owned(),
            serde_json::from_str(args).unwrap_or_default(),
        ))
    } else {
        None
    };
    let said = match knock.map(on_knock) {
        Some(Some(Ok(reply))) => format!("ok {}\n", reply.replace('\n', " ")),
        Some(Some(Err(why))) => format!("no {}\n", why.replace('\n', " ")),
        _ => "ok\n".to_owned(),
    };
    let _ = stream.write_all(said.as_bytes());
}

/// Answers knocks on `listener` until the app leaves: a show or a page on
/// this thread, an ask (which may take a moment) on one of its own.
#[cfg(target_os = "linux")]
fn serve(listener: UnixListener, on_knock: Arc<dyn Fn(Knock) -> Answer + Send + Sync>) {
    let spawned = std::thread::Builder::new()
        .name("sol-single".into())
        .spawn(move || {
            for stream in listener.incoming().flatten() {
                let on_knock = on_knock.clone();
                let asked = std::thread::Builder::new()
                    .name("sol-knock".into())
                    .spawn(move || answer(stream, &*on_knock));
                if let Err(e) = asked {
                    tracing::warn!("no thread for a knock: {e}");
                }
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
    on_knock: impl Fn(Knock) -> Answer + Send + Sync + 'static,
) -> bool {
    #[cfg(target_os = "linux")]
    {
        let listener = match address(world, preview).and_then(|a| UnixListener::bind_addr(&a)) {
            Ok(listener) => listener,
            Err(e) if e.kind() == ErrorKind::AddrInUse => {
                if let Ok(stream) =
                    address(world, preview).and_then(|a| UnixStream::connect_addr(&a))
                {
                    knock_on(stream, knock.as_ref());
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
            knock_on(stream, knock.as_ref());
            return false;
        }
        let on_knock: Arc<dyn Fn(Knock) -> Answer + Send + Sync> = Arc::new(on_knock);
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
            && knock_on(stream, Some(what))
        {
            return true;
        }
        // A world still on a version before 1.0.
        UnixStream::connect(file(world, preview)).is_ok_and(|stream| knock_on(stream, Some(what)))
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = (world, preview, what);
        false
    }
}

/// Asks the running copy of `world` to run its door command `command`
/// (`do`, `find`, `ask`) with `args`, and waits for the reply.
pub fn ask(world: &str, preview: bool, command: &str, args: &serde_json::Value) -> Asked {
    ask_within(
        world,
        preview,
        command,
        args,
        std::time::Duration::from_secs(20),
    )
}

/// [`ask`], waiting at most `wait` for the reply (quick capture's 100 ms).
pub fn ask_within(
    world: &str,
    preview: bool,
    command: &str,
    args: &serde_json::Value,
    wait: std::time::Duration,
) -> Asked {
    #[cfg(target_os = "linux")]
    {
        let Ok(mut stream) = address(world, preview).and_then(|a| UnixStream::connect_addr(&a))
        else {
            return Asked::Nobody;
        };
        let line = Knock::Ask(command.to_owned(), args.clone()).line();
        let _ = stream.set_read_timeout(Some(wait));
        if stream.write_all(line.as_bytes()).is_err() {
            return Asked::Nobody;
        }
        let mut reply = String::new();
        if BufReader::new(stream).read_line(&mut reply).is_err() {
            return Asked::No("no answer in time".into());
        }
        let reply = reply.trim_end();
        if let Some(yes) = reply.strip_prefix("ok ") {
            Asked::Yes(yes.to_owned())
        } else if let Some(no) = reply.strip_prefix("no ") {
            Asked::No(no.to_owned())
        } else if reply.is_empty() {
            Asked::Nobody
        } else {
            Asked::Old
        }
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = (world, preview, command, args, wait);
        Asked::Nobody
    }
}

/// For tests (`testing::FakeDoor`): answers knocks on `world`'s door with
/// `on_knock` until `stop` is set and the door knocked on once more
/// ([`wake_door`]).
#[cfg(feature = "testing")]
pub(crate) fn open_door(
    world: &str,
    stop: Arc<std::sync::atomic::AtomicBool>,
    on_knock: Arc<dyn Fn(Knock) -> Answer + Send + Sync>,
) -> std::io::Result<()> {
    #[cfg(target_os = "linux")]
    {
        let listener = UnixListener::bind_addr(&address(world, false)?)?;
        std::thread::spawn(move || {
            for stream in listener.incoming().flatten() {
                if stop.load(std::sync::atomic::Ordering::SeqCst) {
                    break;
                }
                let on_knock = on_knock.clone();
                std::thread::spawn(move || answer(stream, &*on_knock));
            }
        });
        Ok(())
    }
    #[cfg(not(target_os = "linux"))]
    {
        let _ = (world, stop, on_knock);
        Err(std::io::ErrorKind::Unsupported.into())
    }
}

/// Knocks on a test's door so it sees it should stop.
#[cfg(feature = "testing")]
pub(crate) fn wake_door(world: &str) {
    #[cfg(target_os = "linux")]
    let _ = address(world, false).and_then(|a| UnixStream::connect_addr(&a));
    #[cfg(not(target_os = "linux"))]
    let _ = world;
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
            if let Knock::Ask(command, args) = k {
                return Some(if command == "find" {
                    Ok(format!("[{args}]"))
                } else {
                    Err("no such thing".to_owned())
                });
            }
            let _ = tx.send(match k {
                Knock::Show => "show".to_owned(),
                Knock::Open(p) => p,
                Knock::Ask(..) => unreachable!(),
            });
            None
        }));
        // A second copy finds it and asks for a page.
        assert!(!claim(&world, true, Some(Knock::Open("/x".into())), |_| {
            None
        }));
        assert_eq!(rx.recv().unwrap(), "/x");
        // Through the socket file too, as an older version would.
        let stream = UnixStream::connect(file(&world, true)).unwrap();
        assert!(knock_on(stream, Some(&Knock::Show)));
        assert_eq!(rx.recv().unwrap(), "show");
        assert!(knock(&world, true, &Knock::Show));
        assert_eq!(rx.recv().unwrap(), "show");
        // The desktop asks, and hears the reply.
        let query = serde_json::json!({ "query": "a b" });
        assert!(
            matches!(ask(&world, true, "find", &query), Asked::Yes(r) if r == r#"[{"query":"a b"}]"#)
        );
        assert!(matches!(ask(&world, true, "do", &query), Asked::No(r) if r == "no such thing"));
        assert!(matches!(
            ask(&format!("{world}-none"), true, "do", &query),
            Asked::Nobody
        ));
        leave();
        // `leave` removes the file this process listens on; another test may
        // have claimed its door first and own that one.
        if OWNED.get() == Some(&file(&world, true)) {
            assert!(!file(&world, true).exists());
        } else {
            let _ = std::fs::remove_file(file(&world, true));
        }
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
        assert!(!claim(&world, true, Some(Knock::Show), |_| None));
        assert_eq!(heard.join().unwrap(), "show\n");
        let _ = std::fs::remove_file(&path);
    }
}
