//! The sky (`SkyPage.qml`): what the person has done, as stars that join
//! into named constellations ("100 Nights", "First 500 Words", "The Ghibli
//! Run"). Each world says what its constellations are and which of their
//! stars are reached, from its own data ([`Constellation`]); the kit lights
//! a reached star once, as a document in the world's own collection `sky`
//! (so it syncs and exports, and stays lit if the world later forgets what
//! lit it), tells the screens (the event `sky.lit`, which plays the kit's
//! moment), and lays the whole sky out for the page ([`view`]).
//!
//! Two kinds of star come from the kit itself: **comets**, which cross a
//! world's Sheet on a few days a year and become a star when caught
//! ([`comet_on`], [`catch_comet`]), and **the real sky**: full moons, the
//! Perseids and Saturn's opposition, shown on the Sheet of the world they
//! belong to and lit as a star the first time it is opened that day
//! ([`tonight`]).

use chrono::{DateTime, Datelike, NaiveDate, Utc};
use orbit::link::Link;
use serde::{Deserialize, Serialize};

use crate::moments::occasion_id;

/// Where a world keeps its lit stars.
pub const SKY: &str = "sky";
/// The constellation caught comets join.
pub const COMETS: &str = "comets";
/// The constellation the real sky's nights join.
pub const REAL_SKY: &str = "real-sky";

/// A constellation as the world defines it now.
#[derive(Clone, Debug, Default)]
pub struct Constellation {
    /// Letters, digits and `-`: stays the same for good, as lit stars name it.
    pub id: String,
    pub title: String,
    /// One sentence on what it is made of.
    pub story: String,
    /// In the order they light, which is the order its lines join them.
    pub stars: Vec<Star>,
}

/// A star: one milestone.
#[derive(Clone, Debug, Default)]
pub struct Star {
    /// Unique within its constellation, for good.
    pub id: String,
    pub title: String,
    /// What lighting it took, in a sentence ("A hundred nights logged.").
    pub story: String,
    /// Whether the world's data reaches it now.
    pub reached: bool,
}

impl Constellation {
    pub fn new(id: &str, title: &str, story: &str) -> Self {
        Self {
            id: id.to_owned(),
            title: title.to_owned(),
            story: story.to_owned(),
            stars: Vec::new(),
        }
    }

    /// Adds a star, reached or not.
    pub fn star(mut self, id: &str, title: &str, story: &str, reached: bool) -> Self {
        self.stars.push(Star {
            id: id.to_owned(),
            title: title.to_owned(),
            story: story.to_owned(),
            reached,
        });
        self
    }

    /// Stars at counts of something: `steps(n, &[1, 10, 100], |k| (title,
    /// story))`, each reached once `n` gets there. Its id is the count.
    pub fn steps(mut self, n: u64, at: &[u64], words: impl Fn(u64) -> (String, String)) -> Self {
        for &k in at {
            let (title, story) = words(k);
            self.stars.push(Star {
                id: k.to_string(),
                title,
                story,
                reached: n >= k,
            });
        }
        self
    }
}

/// A star lit, as kept in the world's `sky` collection.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Lit {
    #[serde(default = "first")]
    pub v: u32,
    pub constellation: String,
    /// The constellation's title then, for a sky that no longer defines it.
    #[serde(default)]
    pub constellation_title: String,
    pub star: String,
    pub title: String,
    pub story: String,
    /// When, RFC 3339.
    pub at: String,
}

fn first() -> u32 {
    1
}

impl Lit {
    /// Its document id in `sky`.
    pub fn id(&self) -> String {
        star_id(&self.constellation, &self.star)
    }
}

/// The document id of a constellation's star.
pub fn star_id(constellation: &str, star: &str) -> String {
    occasion_id(&format!("{constellation}.{star}"))
}

/// Every star lit so far, oldest first.
pub async fn lit(link: &Link) -> anyhow::Result<Vec<Lit>> {
    let mut all: Vec<Lit> = link.list_as(SKY).await?;
    all.sort_by(|a, b| a.at.cmp(&b.at));
    Ok(all)
}

/// Lights the reached stars that aren't yet and says which; with `tell`,
/// the screens hear of the newest (`sky.lit`) and play its moment, one at a
/// time. The first time a world's sky is filled (what was reached before
/// the Sky existed) it is lit quietly. A world calls it after a write that
/// may reach a milestone, and its `sky` command does before drawing, so
/// nothing reached is ever missed for long.
pub async fn record(
    link: &Link,
    constellations: &[Constellation],
    tell: bool,
) -> anyhow::Result<Vec<Lit>> {
    let mut reached: Vec<(&Constellation, &Star)> = Vec::new();
    for c in constellations {
        reached.extend(c.stars.iter().filter(|s| s.reached).map(|s| (c, s)));
    }
    let mut new = Vec::new();
    let mut have: Option<Vec<Lit>> = None;
    let mut first = false;
    for (c, s) in reached {
        let have = match &mut have {
            Some(h) => h,
            None => {
                let kept: Vec<Lit> = link.list_as(SKY).await?;
                first = kept.is_empty();
                have.insert(kept)
            }
        };
        if have
            .iter()
            .any(|l| l.constellation == c.id && l.star == s.id)
        {
            continue;
        }
        let l = light(link, c, s).await?;
        have.push(l.clone());
        new.push(l);
    }
    if tell
        && !first
        && let Some(l) = new.last()
    {
        crate::emit_in(link.world(), "sky.lit", l);
    }
    Ok(new)
}

async fn light(link: &Link, c: &Constellation, s: &Star) -> anyhow::Result<Lit> {
    let l = Lit {
        v: 1,
        constellation: c.id.clone(),
        constellation_title: c.title.clone(),
        star: s.id.clone(),
        title: s.title.clone(),
        story: s.story.clone(),
        at: Utc::now().to_rfc3339(),
    };
    link.put_as(SKY, &l.id(), &l).await?;
    Ok(l)
}

// ---- The page --------------------------------------------------------------

/// The sky as the page draws it.
#[derive(Clone, Debug, Serialize)]
pub struct View {
    pub constellations: Vec<PlacedConstellation>,
    pub stars: Vec<PlacedStar>,
    /// Each line between two stars, by their keys; `lit` when both are.
    pub lines: Vec<Line>,
    pub lit: usize,
    pub total: usize,
}

#[derive(Clone, Debug, Serialize)]
pub struct PlacedConstellation {
    pub id: String,
    pub title: String,
    pub story: String,
    /// Where its name goes: above its highest star.
    pub x: f64,
    pub y: f64,
    pub lit: usize,
    pub total: usize,
}

#[derive(Clone, Debug, Serialize)]
pub struct PlacedStar {
    /// `<constellation>/<star>`, unique in the sky.
    pub key: String,
    pub constellation: String,
    pub title: String,
    pub story: String,
    pub x: f64,
    pub y: f64,
    pub lit: bool,
    /// When it was lit, RFC 3339.
    pub at: Option<String>,
}

#[derive(Clone, Debug, Serialize)]
pub struct Line {
    pub a: String,
    pub b: String,
    pub lit: bool,
}

/// The world's constellations with what is lit, laid out: the comets and
/// the real sky's nights after the world's own, and a lit star the world no
/// longer defines kept in its constellation (one that has gone entirely
/// comes back under its old title). Each constellation gets a cell of the
/// sky, about 2.4 wide and 1.6 high around 0, and its stars walk across it
/// in order; where everything sits follows from the ids alone, so the sky
/// is the same every time and on every device.
pub fn view(defined: &[Constellation], lit: &[Lit]) -> View {
    let mut all: Vec<Constellation> = defined.to_vec();
    for l in lit {
        let c = match all.iter_mut().position(|c| c.id == l.constellation) {
            Some(i) => &mut all[i],
            None => {
                let (title, story) = match l.constellation.as_str() {
                    COMETS => ("Comets", "Comets caught as they crossed the Sheet."),
                    REAL_SKY => ("Under the real sky", "Nights the sky itself put on a show."),
                    _ => (l.constellation_title.as_str(), ""),
                };
                all.push(Constellation::new(&l.constellation, title, story));
                all.last_mut().expect("just pushed")
            }
        };
        if !c.stars.iter().any(|s| s.id == l.star) {
            c.stars.push(Star {
                id: l.star.clone(),
                title: l.title.clone(),
                story: l.story.clone(),
                reached: true,
            });
        }
    }
    // The kit's own two go last, comets at the very end.
    let rank = |c: &Constellation| match c.id.as_str() {
        REAL_SKY => 1,
        COMETS => 2,
        _ => 0,
    };
    all.sort_by_key(rank);
    all.retain(|c| !c.stars.is_empty());

    let n = all.len().max(1);
    let cols = ((n as f64 * 1.5).sqrt().ceil() as usize).clamp(1, 4);
    let rows = n.div_ceil(cols);
    let (cw, ch) = (2.4 / cols as f64, 1.6 / rows as f64);

    let mut out = View {
        constellations: Vec::new(),
        stars: Vec::new(),
        lines: Vec::new(),
        lit: 0,
        total: 0,
    };
    for (i, c) in all.iter().enumerate() {
        let (col, row) = (i % cols, i / cols);
        // A row with fewer constellations is centred.
        let in_row = if row == rows - 1 {
            n - row * cols
        } else {
            cols
        };
        let shift = (cols - in_row) as f64 * cw / 2.0;
        let mut rng = Seed::of(&c.id);
        let cx = -1.2 + cw * (col as f64 + 0.5) + shift + rng.between(-0.08, 0.08) * cw;
        let cy = -0.8 + ch * (row as f64 + 0.5) + rng.between(-0.06, 0.06) * ch;
        // A walk across the cell: steps a little shorter as the stars get more.
        let count = c.stars.len();
        let span = (cw * 0.8).min(1.0);
        let step = span / (count.max(2) - 1) as f64;
        let mut heading = rng.between(-0.5, 0.5);
        let (mut x, mut y) = (cx - span / 2.0, cy + rng.between(-0.1, 0.1) * ch);
        let mut points = Vec::with_capacity(count);
        for _ in 0..count {
            points.push((x, y));
            heading += rng.between(-0.9, 0.9);
            heading = heading.clamp(-1.0, 1.0);
            x += step * heading.cos();
            y += step * heading.sin() * 1.1;
            // Kept inside the cell.
            y = y.clamp(cy - ch * 0.36, cy + ch * 0.36);
        }
        // Centred on the cell.
        let (mx, my) = points
            .iter()
            .fold((0.0, 0.0), |(a, b), p| (a + p.0, b + p.1));
        let (dx, dy) = (cx - mx / count as f64, cy - my / count as f64);

        let mut lit_here = 0;
        let mut previous: Option<(String, bool)> = None;
        let mut top = f64::MAX;
        for (s, (x, y)) in c.stars.iter().zip(points) {
            let kept = lit
                .iter()
                .find(|l| l.constellation == c.id && l.star == s.id);
            let on = kept.is_some();
            lit_here += usize::from(on);
            let key = format!("{}/{}", c.id, s.id);
            let (x, y) = (x + dx, y + dy);
            top = top.min(y);
            if let Some((a, a_on)) = previous.take() {
                out.lines.push(Line {
                    a,
                    b: key.clone(),
                    lit: a_on && on,
                });
            }
            previous = Some((key.clone(), on));
            out.stars.push(PlacedStar {
                key,
                constellation: c.id.clone(),
                title: s.title.clone(),
                story: s.story.clone(),
                x: round(x),
                y: round(y),
                lit: on,
                at: kept.map(|l| l.at.clone()),
            });
        }
        out.lit += lit_here;
        out.total += count;
        out.constellations.push(PlacedConstellation {
            id: c.id.clone(),
            title: c.title.clone(),
            story: c.story.clone(),
            x: round(cx),
            y: round(top - 0.07),
            lit: lit_here,
            total: count,
        });
    }
    out
}

fn round(v: f64) -> f64 {
    (v * 10_000.0).round() / 10_000.0
}

/// A small sequence of numbers from a name: the same name, the same sky.
struct Seed(u64);

impl Seed {
    fn of(name: &str) -> Self {
        Self(fingerprint(name) | 1)
    }
    fn next(&mut self) -> f64 {
        // xorshift64*
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        (self.0.wrapping_mul(0x2545_f491_4f6c_dd1d) >> 11) as f64 / (1u64 << 53) as f64
    }
    fn between(&mut self, a: f64, b: f64) -> f64 {
        a + (b - a) * self.next()
    }
}

fn fingerprint(text: &str) -> u64 {
    // FNV-1a, as moments: stable across runs and versions.
    text.bytes().fold(0xcbf2_9ce4_8422_2325, |h, b| {
        (h ^ u64::from(b)).wrapping_mul(0x0100_0000_01b3)
    })
}

/// The sky the page draws: the world's constellations, with what they
/// reach lit first (each new one told, so it plays its moment).
pub async fn show(link: &Link, constellations: &[Constellation]) -> anyhow::Result<View> {
    record(link, constellations, true).await?;
    Ok(view(constellations, &lit(link).await?))
}

// ---- Comets ----------------------------------------------------------------

/// About how many days a year a comet crosses a world's Sheet, in a
/// thousand: 11 is about four a year.
const COMET_ODDS: u64 = 11;

/// Whether a comet crosses this world's Sheet on `day`. Each world has its
/// own few days a year, the same on every device.
pub fn comet_on(world: &str, day: NaiveDate) -> bool {
    fingerprint(&format!("comet.{world}.{day}")) % 1000 < COMET_ODDS
}

/// Today's comet for the Sheet: its day when one crosses and it hasn't been
/// caught, else none.
pub async fn comet(link: &Link, today: NaiveDate) -> anyhow::Result<Option<NaiveDate>> {
    if !comet_on(link.world(), today) {
        return Ok(None);
    }
    let caught = link
        .get(SKY, &star_id(COMETS, &today.to_string()))
        .await?
        .is_some();
    Ok((!caught).then_some(today))
}

/// A comet caught: its star in "Comets". Only a comet's own day lights one.
pub async fn catch_comet(link: &Link, day: NaiveDate, name: &str) -> anyhow::Result<Lit> {
    anyhow::ensure!(comet_on(link.world(), day), "no comet crossed on {day}");
    let c = Constellation::new(COMETS, "Comets", "");
    let s = Star {
        id: day.to_string(),
        title: format!("The comet of {}", long_date(day)),
        story: format!("Caught as it crossed {name}'s sky."),
        reached: true,
    };
    if let Some(l) = link.get_as::<Lit>(SKY, &star_id(COMETS, &s.id)).await? {
        return Ok(l);
    }
    light(link, &c, &s).await
}

fn long_date(day: NaiveDate) -> String {
    const MONTHS: [&str; 12] = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
    ];
    format!(
        "{} {} {}",
        day.day(),
        MONTHS[day.month0() as usize],
        day.year()
    )
}

// ---- The real sky ----------------------------------------------------------

/// Something in the real sky tonight, for the world it belongs to.
#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct Event {
    /// `full-moon-2026-10-26`, `perseids-2026`, `saturn-opposition-2026`.
    pub id: String,
    /// `full-moon`, `perseids`, `opposition`.
    pub kind: String,
    /// The world whose Sheet shows it.
    pub world: String,
    /// "Full moon tonight".
    pub title: String,
    /// What it means for the person, a short line.
    pub line: String,
    /// The star it lights: "Full moon, 26 October 2026".
    pub star: String,
}

/// The Perseids peak on the night of 12 to 13 August, every year.
const PERSEIDS: (u32, u32) = (8, 12);

/// Saturn's oppositions (closest and brightest, up all night), from the
/// published almanacs; one a year, about two weeks later each time.
const SATURN_OPPOSITIONS: [(i32, u32, u32); 7] = [
    (2025, 9, 21),
    (2026, 10, 4),
    (2027, 10, 18),
    (2028, 10, 30),
    (2029, 11, 13),
    (2030, 11, 27),
    (2031, 12, 11),
];

/// What the real sky has on `day` (in the zone of `zone_of`), for `world`.
pub fn events_on(
    world: &str,
    day: NaiveDate,
    zone_of: impl Fn(DateTime<Utc>) -> NaiveDate,
) -> Vec<Event> {
    let mut out = Vec::new();
    if world == "luna" {
        if full_moons_around(day)
            .into_iter()
            .any(|t| zone_of(t) == day)
        {
            out.push(Event {
                id: format!("full-moon-{day}"),
                kind: "full-moon".into(),
                world: world.into(),
                title: "Full moon tonight".into(),
                line: format!("The {} is up all night.", moon_name(day.month())),
                star: format!("The {}, {}", moon_name(day.month()), long_date(day)),
            });
        }
        if (day.month(), day.day()) == PERSEIDS {
            out.push(Event {
                id: format!("perseids-{}", day.year()),
                kind: "perseids".into(),
                world: world.into(),
                title: "The Perseids tonight".into(),
                line: "Up to a hundred shooting stars an hour after midnight. Stay up a little?"
                    .into(),
                star: format!("The Perseids, {}", day.year()),
            });
        }
    }
    if world == "saturn"
        && SATURN_OPPOSITIONS
            .iter()
            .any(|&(y, m, d)| NaiveDate::from_ymd_opt(y, m, d) == Some(day))
    {
        out.push(Event {
            id: format!("saturn-opposition-{}", day.year()),
            kind: "opposition".into(),
            world: world.into(),
            title: "Saturn at its brightest".into(),
            line: "Closest to us this year and up all night: look south-east after dark.".into(),
            star: format!("Saturn at opposition, {}", long_date(day)),
        });
    }
    out
}

/// Tonight's sky for the world's Sheet, each event lit as a star in "Under
/// the real sky" the first time (quietly: the Sheet is its moment).
pub async fn tonight(link: &Link) -> anyhow::Result<Vec<Event>> {
    let clock = orbit::clock::Clock::calendar(link);
    let tz = link.time_zone();
    let events = events_on(link.world(), clock.today(), |t| {
        t.with_timezone(&tz).date_naive()
    });
    if !events.is_empty() {
        let c = Constellation {
            id: REAL_SKY.into(),
            title: "Under the real sky".into(),
            story: String::new(),
            stars: events
                .iter()
                .map(|e| Star {
                    id: e.id.clone(),
                    title: e.star.clone(),
                    story: e.line.clone(),
                    reached: true,
                })
                .collect(),
        };
        record(link, &[c], false).await?;
    }
    Ok(events)
}

/// The full moons' old names, by month.
fn moon_name(month: u32) -> &'static str {
    [
        "Wolf Moon",
        "Snow Moon",
        "Worm Moon",
        "Pink Moon",
        "Flower Moon",
        "Strawberry Moon",
        "Buck Moon",
        "Sturgeon Moon",
        "Harvest Moon",
        "Hunter's Moon",
        "Beaver Moon",
        "Cold Moon",
    ][(month as usize + 11) % 12]
}

/// The full moons nearest `day`, to the minute or so (Meeus, "Astronomical
/// Algorithms", chapter 49, with its larger terms).
pub fn full_moons_around(day: NaiveDate) -> Vec<DateTime<Utc>> {
    let years = day.year() as f64 + (day.ordinal() as f64 - 0.5) / 365.25;
    let k0 = ((years - 2000.0) * 12.3685).floor();
    [-1.0, 0.0, 1.0, 2.0]
        .iter()
        .filter_map(|o| full_moon(k0 + o + 0.5))
        .collect()
}

/// The full moon of lunation `k` (a whole number and a half).
fn full_moon(k: f64) -> Option<DateTime<Utc>> {
    let t = k / 1236.85;
    let jde =
        2_451_550.097_66 + 29.530_588_861 * k + 0.000_154_37 * t * t - 0.000_000_150 * t * t * t;
    let e = 1.0 - 0.002_516 * t - 0.000_007_4 * t * t;
    let rad = |d: f64| d.rem_euclid(360.0).to_radians();
    let m = rad(2.5534 + 29.105_356_70 * k - 0.000_001_4 * t * t);
    let mp = rad(201.5643 + 385.816_935_28 * k + 0.010_758_2 * t * t);
    let f = rad(160.7108 + 390.670_502_84 * k - 0.001_611_8 * t * t);
    let om = rad(124.7746 - 1.563_755_88 * k + 0.002_067_2 * t * t);
    let c = -0.40614 * mp.sin()
        + 0.17302 * e * m.sin()
        + 0.01614 * (2.0 * mp).sin()
        + 0.01043 * (2.0 * f).sin()
        + 0.00734 * e * (mp - m).sin()
        - 0.00515 * e * (mp + m).sin()
        + 0.00209 * e * e * (2.0 * m).sin()
        - 0.00111 * (mp - 2.0 * f).sin()
        - 0.00057 * (mp + 2.0 * f).sin()
        + 0.00056 * e * (2.0 * mp + m).sin()
        - 0.00042 * (3.0 * mp).sin()
        + 0.00042 * e * (m + 2.0 * f).sin()
        + 0.00038 * e * (m - 2.0 * f).sin()
        - 0.00024 * e * (2.0 * mp - m).sin()
        - 0.00017 * om.sin();
    let jde = jde + c;
    // Julian day to Unix time; TT and UTC differ by about a minute, left be.
    let secs = (jde - 2_440_587.5) * 86_400.0;
    DateTime::from_timestamp(secs.round() as i64, 0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use orbit::testing::offline;

    fn nights() -> Constellation {
        Constellation::new("nights", "100 Nights", "Nights logged.").steps(12, &[1, 10, 100], |k| {
            (format!("{k} nights"), format!("{k} nights logged."))
        })
    }

    #[tokio::test]
    async fn a_reached_star_is_lit_once() {
        let (link, _dir) = offline("gallery").await;
        let new = record(&link, &[nights()], false).await.unwrap();
        assert_eq!(
            new.iter().map(|l| l.star.as_str()).collect::<Vec<_>>(),
            ["1", "10"]
        );
        assert!(record(&link, &[nights()], false).await.unwrap().is_empty());
        let kept: Lit = link.get_as(SKY, "nights_10").await.unwrap().unwrap();
        assert_eq!(kept.title, "10 nights");
        assert_eq!(kept.constellation_title, "100 Nights");
    }

    #[tokio::test]
    async fn a_lit_star_stays_when_the_world_forgets_it() {
        let (link, _dir) = offline("gallery").await;
        record(&link, &[nights()], false).await.unwrap();
        // The world no longer defines "nights" at all.
        let v = view(&[], &lit(&link).await.unwrap());
        assert_eq!(v.constellations.len(), 1);
        assert_eq!(v.constellations[0].title, "100 Nights");
        assert_eq!((v.lit, v.total), (2, 2));
    }

    #[test]
    fn the_sky_is_laid_out_the_same_every_time() {
        let defs = [
            nights(),
            Constellation::new("words", "First 500 Words", "").steps(
                0,
                &[50, 100, 250, 500],
                |k| (k.to_string(), String::new()),
            ),
        ];
        let a = view(&defs, &[]);
        let b = view(&defs, &[]);
        assert_eq!(
            serde_json::to_string(&a).unwrap(),
            serde_json::to_string(&b).unwrap()
        );
        assert_eq!((a.lit, a.total), (0, 7));
        assert_eq!(a.lines.len(), 2 + 3, "each star joins the one before");
        for s in &a.stars {
            assert!(
                s.x.abs() <= 1.25 && s.y.abs() <= 0.85,
                "{} sits in the sky: {s:?}",
                s.key
            );
        }
        // Two constellations don't sit on top of each other.
        let (c1, c2) = (&a.constellations[0], &a.constellations[1]);
        assert!((c1.x - c2.x).abs() + (c1.y - c2.y).abs() > 0.5);
    }

    #[test]
    fn comets_come_a_few_times_a_year() {
        for world in [
            "terra", "luna", "saturn", "titan", "mercury", "neptune", "triton",
        ] {
            let start = NaiveDate::from_ymd_opt(2026, 1, 1).unwrap();
            let days: Vec<NaiveDate> = start
                .iter_days()
                .take(365 * 4)
                .filter(|d| comet_on(world, *d))
                .collect();
            assert!(
                (6..=30).contains(&days.len()),
                "{world}: {} in four years",
                days.len()
            );
        }
    }

    #[tokio::test]
    async fn a_comet_is_caught_on_its_day_only() {
        let (link, _dir) = offline("gallery").await;
        let start = NaiveDate::from_ymd_opt(2026, 1, 1).unwrap();
        let day = start.iter_days().find(|d| comet_on("gallery", *d)).unwrap();
        let other = start
            .iter_days()
            .find(|d| !comet_on("gallery", *d))
            .unwrap();
        assert_eq!(comet(&link, day).await.unwrap(), Some(day));
        assert_eq!(comet(&link, other).await.unwrap(), None);
        assert!(catch_comet(&link, other, "Gallery").await.is_err());
        let l = catch_comet(&link, day, "Gallery").await.unwrap();
        assert_eq!(l.constellation, COMETS);
        assert!(l.story.contains("Gallery's sky"));
        // Caught, it no longer crosses.
        assert_eq!(comet(&link, day).await.unwrap(), None);
        let v = view(&[], &lit(&link).await.unwrap());
        assert_eq!(v.constellations[0].title, "Comets");
    }

    #[test]
    fn full_moons_fall_where_the_almanac_puts_them() {
        // Published times (UTC) of full moons, to within the hour.
        let known = [
            "2025-01-13T22:27:00Z",
            "2025-09-07T18:09:00Z",
            "2026-03-03T11:38:00Z",
            "2026-10-26T04:12:00Z",
            "2000-01-21T04:40:00Z",
        ];
        for k in known {
            let want: DateTime<Utc> = k.parse().unwrap();
            let got = full_moons_around(want.date_naive());
            let closest = got
                .iter()
                .map(|t| (*t - want).num_minutes().abs())
                .min()
                .unwrap();
            assert!(closest <= 30, "{k}: off by {closest} minutes ({got:?})");
        }
    }

    #[test]
    fn the_real_sky_belongs_to_its_world() {
        let utc = |t: DateTime<Utc>| t.date_naive();
        let full = NaiveDate::from_ymd_opt(2026, 10, 26).unwrap();
        let luna = events_on("luna", full, utc);
        assert_eq!(luna.len(), 1);
        assert_eq!(luna[0].id, "full-moon-2026-10-26");
        assert!(luna[0].line.contains("Hunter's Moon"));
        assert!(events_on("terra", full, utc).is_empty());
        assert!(events_on("luna", full.pred_opt().unwrap(), utc).is_empty());
        let perseids = NaiveDate::from_ymd_opt(2027, 8, 12).unwrap();
        assert!(
            events_on("luna", perseids, utc)
                .iter()
                .any(|e| e.kind == "perseids")
        );
        let opposition = NaiveDate::from_ymd_opt(2026, 10, 4).unwrap();
        assert_eq!(events_on("saturn", opposition, utc)[0].kind, "opposition");
        assert!(
            events_on("luna", opposition, utc)
                .iter()
                .all(|e| e.kind != "opposition")
        );
    }

    #[tokio::test]
    async fn the_real_sky_lights_its_star_once() {
        let (link, _dir) = offline("luna").await;
        // Whatever tonight is, lighting is the same as for any star.
        let c = Constellation::new(REAL_SKY, "Under the real sky", "").star(
            "full-moon-2026-10-26",
            "Full moon",
            "",
            true,
        );
        assert_eq!(
            record(&link, std::slice::from_ref(&c), false)
                .await
                .unwrap()
                .len(),
            1
        );
        assert!(record(&link, &[c], false).await.unwrap().is_empty());
        let v = view(&[], &lit(&link).await.unwrap());
        assert_eq!(v.constellations[0].title, "Under the real sky");
    }
}
