//! What the stand-in serves besides JSON: covers drawn as PNGs (a
//! gradient and a ring in colours of the id's own) and streams of silence
//! as WAV, both made without any library.

use super::library::hash;

/// A cover's side, in pixels.
const SIDE: u32 = 300;
/// The streams: 8-bit mono at this rate, silence (128) throughout.
const RATE: u32 = 22_050;

/// A cover for an id: the same picture every time.
pub fn cover(id: &str) -> Vec<u8> {
    let seed = hash(&id.bytes().map(u64::from).collect::<Vec<_>>());
    let hue = (seed % 360) as f32;
    let from = rgb(hue, 0.55, 0.30);
    let to = rgb((hue + 40.0 + (seed >> 9) as f32 % 80.0) % 360.0, 0.60, 0.62);
    let ring = rgb((hue + 180.0) % 360.0, 0.35, 0.85);
    // Palette: 0-199 the gradient, 200-255 the ring fading into it.
    let mut palette = Vec::with_capacity(256 * 3);
    for i in 0..256u32 {
        let c = if i < 200 {
            mix(from, to, i as f32 / 199.0)
        } else {
            mix(mix(from, to, 0.5), ring, (i - 199) as f32 / 56.0)
        };
        palette.extend_from_slice(&c);
    }
    let (cx, cy) = (
        SIDE as f32 * (0.3 + (seed >> 20) as f32 % 40.0 / 100.0),
        SIDE as f32 * (0.3 + (seed >> 28) as f32 % 40.0 / 100.0),
    );
    let radius = SIDE as f32 * (0.18 + (seed >> 36) as f32 % 14.0 / 100.0);
    let mut rows = Vec::with_capacity(((SIDE + 1) * SIDE) as usize);
    for y in 0..SIDE {
        rows.push(0); // no filter
        for x in 0..SIDE {
            let t = (x + y) as f32 / (2 * SIDE - 2) as f32;
            let d = ((x as f32 - cx).hypot(y as f32 - cy) - radius).abs();
            rows.push(if d < 7.0 {
                255 - (d * 8.0) as u8
            } else {
                (t * 199.0) as u8
            });
        }
    }
    png(SIDE, SIDE, &palette, &rows)
}

fn rgb(h: f32, s: f32, l: f32) -> [u8; 3] {
    let c = (1.0 - (2.0 * l - 1.0).abs()) * s;
    let x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
    let (r, g, b) = match (h / 60.0) as u32 {
        0 => (c, x, 0.0),
        1 => (x, c, 0.0),
        2 => (0.0, c, x),
        3 => (0.0, x, c),
        4 => (x, 0.0, c),
        _ => (c, 0.0, x),
    };
    let m = l - c / 2.0;
    [r, g, b].map(|v| ((v + m) * 255.0).round().clamp(0.0, 255.0) as u8)
}

fn mix(a: [u8; 3], b: [u8; 3], t: f32) -> [u8; 3] {
    [0, 1, 2].map(|i| (a[i] as f32 + (b[i] as f32 - a[i] as f32) * t) as u8)
}

/// A paletted PNG of filtered `rows`, its pixels in stored (uncompressed)
/// deflate blocks.
fn png(width: u32, height: u32, palette: &[u8], rows: &[u8]) -> Vec<u8> {
    let mut out = b"\x89PNG\r\n\x1a\n".to_vec();
    let mut header = Vec::new();
    header.extend_from_slice(&width.to_be_bytes());
    header.extend_from_slice(&height.to_be_bytes());
    header.extend_from_slice(&[8, 3, 0, 0, 0]);
    chunk(&mut out, b"IHDR", &header);
    chunk(&mut out, b"PLTE", palette);
    let mut z = vec![0x78, 0x01];
    let blocks: Vec<&[u8]> = rows.chunks(65_535).collect();
    for (i, block) in blocks.iter().enumerate() {
        z.push(u8::from(i + 1 == blocks.len()));
        let len = block.len() as u16;
        z.extend_from_slice(&len.to_le_bytes());
        z.extend_from_slice(&(!len).to_le_bytes());
        z.extend_from_slice(block);
    }
    z.extend_from_slice(&adler32(rows).to_be_bytes());
    chunk(&mut out, b"IDAT", &z);
    chunk(&mut out, b"IEND", &[]);
    out
}

fn chunk(out: &mut Vec<u8>, kind: &[u8; 4], data: &[u8]) {
    out.extend_from_slice(&(data.len() as u32).to_be_bytes());
    let start = out.len();
    out.extend_from_slice(kind);
    out.extend_from_slice(data);
    let crc = crc32(&out[start..]);
    out.extend_from_slice(&crc.to_be_bytes());
}

fn crc32(bytes: &[u8]) -> u32 {
    let mut crc = !0u32;
    for &b in bytes {
        crc ^= u32::from(b);
        for _ in 0..8 {
            crc = if crc & 1 == 1 {
                (crc >> 1) ^ 0xEDB8_8320
            } else {
                crc >> 1
            };
        }
    }
    !crc
}

fn adler32(bytes: &[u8]) -> u32 {
    let (mut a, mut b) = (1u32, 0u32);
    for &x in bytes {
        a = (a + u32::from(x)) % 65_521;
        b = (b + a) % 65_521;
    }
    (b << 16) | a
}

/// A track's stream: a WAV header and `seconds` of silence, as a length
/// and a way to read any part of it.
pub struct Silence {
    header: [u8; 44],
    pub len: u64,
}

impl Silence {
    pub fn new(seconds: u32) -> Self {
        let data = seconds * RATE;
        let mut h = [0u8; 44];
        h[0..4].copy_from_slice(b"RIFF");
        h[4..8].copy_from_slice(&(36 + data).to_le_bytes());
        h[8..16].copy_from_slice(b"WAVEfmt ");
        h[16..20].copy_from_slice(&16u32.to_le_bytes());
        h[20..22].copy_from_slice(&1u16.to_le_bytes()); // PCM
        h[22..24].copy_from_slice(&1u16.to_le_bytes()); // mono
        h[24..28].copy_from_slice(&RATE.to_le_bytes());
        h[28..32].copy_from_slice(&RATE.to_le_bytes()); // bytes a second
        h[32..34].copy_from_slice(&1u16.to_le_bytes()); // bytes a frame
        h[34..36].copy_from_slice(&8u16.to_le_bytes()); // bits a sample
        h[36..40].copy_from_slice(b"data");
        h[40..44].copy_from_slice(&data.to_le_bytes());
        Self {
            header: h,
            len: 44 + u64::from(data),
        }
    }

    /// Bytes `from..to` of the file.
    pub fn read(&self, from: u64, to: u64, out: &mut Vec<u8>) {
        out.clear();
        for at in from..to.min(self.len) {
            out.push(self.header.get(at as usize).copied().unwrap_or(128));
        }
    }

    /// Bits a second, as Subsonic counts a bit rate (kbps).
    pub fn kbps() -> u32 {
        RATE * 8 / 1000
    }
}
