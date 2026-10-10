//! The stand-in's HTTP: one thread a connection, one request each (the
//! answer says `Connection: close`), GET and HEAD, ranges for streams.

use std::{
    io::{BufRead, BufReader, Write},
    net::{TcpListener, TcpStream},
};

use super::{FakeNavidrome, api, media};

/// Answers every connection until the app ends.
pub fn serve(listener: TcpListener, fake: &FakeNavidrome) {
    for stream in listener.incoming() {
        let Ok(stream) = stream else { continue };
        let fake = fake.clone();
        let _ = std::thread::Builder::new()
            .name("fake-navidrome-request".into())
            .spawn(move || {
                if let Err(e) = answer(stream, &fake) {
                    tracing::debug!("the stand-in Navidrome's answer broke off: {e}");
                }
            });
    }
}

/// One request: its method, path, query and the range asked for.
struct Request {
    head: bool,
    endpoint: String,
    query: Vec<(String, String)>,
    range: Option<String>,
}

fn read(stream: &TcpStream) -> std::io::Result<Option<Request>> {
    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    reader.read_line(&mut line)?;
    let mut parts = line.split_whitespace();
    let (Some(method), Some(target)) = (parts.next(), parts.next()) else {
        return Ok(None);
    };
    let mut range = None;
    loop {
        let mut header = String::new();
        if reader.read_line(&mut header)? == 0 || header.trim().is_empty() {
            break;
        }
        if let Some((name, value)) = header.split_once(':')
            && name.trim().eq_ignore_ascii_case("range")
        {
            range = Some(value.trim().to_owned());
        }
    }
    let (path, query) = target.split_once('?').unwrap_or((target, ""));
    let endpoint = path
        .trim_start_matches("/rest/")
        .trim_end_matches(".view")
        .to_owned();
    Ok(Some(Request {
        head: method == "HEAD",
        endpoint,
        query: query
            .split('&')
            .filter(|p| !p.is_empty())
            .map(|p| {
                let (k, v) = p.split_once('=').unwrap_or((p, ""));
                (decode(k), decode(v))
            })
            .collect(),
        range,
    }))
}

fn answer(mut stream: TcpStream, fake: &FakeNavidrome) -> std::io::Result<()> {
    let Some(req) = read(&stream)? else {
        return Ok(());
    };
    let param = |k: &str| {
        req.query
            .iter()
            .find(|(key, _)| key == k)
            .map(|(_, v)| v.as_str())
    };
    match req.endpoint.as_str() {
        "getCoverArt" => {
            let picture = media::cover(param("id").unwrap_or("none"));
            let head = format!(
                "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: {}\r\n\
                 Last-Modified: Sun, 14 Sep 2025 19:30:00 GMT\r\nConnection: close\r\n\r\n",
                picture.len()
            );
            stream.write_all(head.as_bytes())?;
            if !req.head {
                stream.write_all(&picture)?;
            }
        }
        "stream" | "download" => {
            let seconds = param("id")
                .and_then(|id| fake.library.song(id))
                .map_or(0, |s| s.duration);
            if seconds == 0 {
                return stream.write_all(
                    b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
                );
            }
            let file = media::Silence::new(seconds);
            let (from, to, partial) = span(req.range.as_deref(), file.len);
            let status = if partial {
                format!(
                    "206 Partial Content\r\nContent-Range: bytes {from}-{}/{}",
                    to - 1,
                    file.len
                )
            } else {
                "200 OK".to_owned()
            };
            let head = format!(
                "HTTP/1.1 {status}\r\nContent-Type: audio/wav\r\nContent-Length: {}\r\n\
                 Accept-Ranges: bytes\r\nConnection: close\r\n\r\n",
                to - from
            );
            stream.write_all(head.as_bytes())?;
            if !req.head {
                let mut buf = Vec::with_capacity(64 * 1024);
                let mut at = from;
                while at < to {
                    let end = (at + 64 * 1024).min(to);
                    file.read(at, end, &mut buf);
                    stream.write_all(&buf)?;
                    at = end;
                }
            }
        }
        endpoint => {
            let body = api::answer(fake, endpoint, &req.query).to_string();
            let head = format!(
                "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\n\
                 Connection: close\r\n\r\n",
                body.len()
            );
            stream.write_all(head.as_bytes())?;
            if !req.head {
                stream.write_all(body.as_bytes())?;
            }
        }
    }
    stream.flush()
}

/// The bytes a `Range` header asks for (`bytes=a-b`, `bytes=a-`,
/// `bytes=-n`) of a file `len` long: from, to (exclusive), and whether it
/// is a part.
fn span(range: Option<&str>, len: u64) -> (u64, u64, bool) {
    let Some(spec) = range.and_then(|r| r.strip_prefix("bytes=")) else {
        return (0, len, false);
    };
    let (a, b) = spec.split_once('-').unwrap_or((spec, ""));
    match (a.trim().parse::<u64>(), b.trim().parse::<u64>()) {
        (Err(_), Ok(n)) => (len.saturating_sub(n), len, true),
        (Ok(a), Ok(b)) if a <= b && a < len => (a, (b + 1).min(len), true),
        (Ok(a), Err(_)) if a < len => (a, len, true),
        _ => (0, len, false),
    }
}

/// A query value with its `%xx` and `+` undone.
fn decode(s: &str) -> String {
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        match bytes[i] {
            b'+' => out.push(b' '),
            b'%' if i + 2 < bytes.len() => {
                let hex = std::str::from_utf8(&bytes[i + 1..i + 3]).unwrap_or("");
                match u8::from_str_radix(hex, 16) {
                    Ok(b) => {
                        out.push(b);
                        i += 2;
                    }
                    Err(_) => out.push(b'%'),
                }
            }
            b => out.push(b),
        }
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ranges_and_values() {
        assert_eq!(span(None, 100), (0, 100, false));
        assert_eq!(span(Some("bytes=-10"), 100), (90, 100, true));
        assert_eq!(span(Some("bytes=10-19"), 100), (10, 20, true));
        assert_eq!(span(Some("bytes=50-"), 100), (50, 100, true));
        assert_eq!(span(Some("bytes=500-"), 100), (0, 100, false));
        assert_eq!(decode("Chill+%26+Study"), "Chill & Study");
        assert_eq!(decode("Triton%3A%20Blue"), "Triton: Blue");
        assert_eq!(decode("100%"), "100%");
    }
}
