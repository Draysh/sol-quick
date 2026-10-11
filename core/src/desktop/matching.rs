//! How sure a world is of a line: one scale for every world, so quick
//! capture's ranking across worlds means the same thing everywhere (the
//! best offer of all the running worlds is the one shown).
//!
//! | Sure | When |
//! | --- | --- |
//! | [`EXACT`] 1.0 | the line is one of your names, as written ("Read" for the habit Read) |
//! | [`VERB`] 0.9 | one of your verbs, with all it needs ("bedtime", "rate 8", "watched frieren") |
//! | [`PREFIX`] 0.8 | a name starts with what was typed ("walk" for Walk outside) |
//! | [`ALL_WORDS`] 0.7 | every word typed is in a name ("drive night" for Night Drive) |
//! | [`SOME_WORD`] 0.5 | one word typed is a word of a name ("walk the dog" for Walk) |
//! | [`GUESS`] 0.3 | yours, but likely not what was meant (nothing playing to pause) |
//!
//! A name after a verb is at most as sure as the verb ([`after_verb`]):
//! "watched frieren" is 0.9, "watched frie" 0.8.

/// The line is one of the world's names, as written.
pub const EXACT: f64 = 1.0;
/// One of the world's verbs, with all it needs.
pub const VERB: f64 = 0.9;
/// A name starts with what was typed.
pub const PREFIX: f64 = 0.8;
/// Every word typed is in a name.
pub const ALL_WORDS: f64 = 0.7;
/// One word typed is a whole word of a name.
pub const SOME_WORD: f64 = 0.5;
/// The world's own words, but likely not what was meant.
pub const GUESS: f64 = 0.3;

/// Lowercased, its spaces made single.
fn plain(text: &str) -> String {
    text.split_whitespace()
        .map(str::to_lowercase)
        .collect::<Vec<_>>()
        .join(" ")
}

/// How well `typed` names `name`, on the scale above; None when it
/// doesn't at all. A word of one or two letters counts only where it
/// starts one of the name's words, so "ea" isn't Read.
pub fn score(typed: &str, name: &str) -> Option<f64> {
    let (typed, name) = (plain(typed), plain(name));
    if typed.is_empty() || name.is_empty() {
        return None;
    }
    if typed == name {
        return Some(EXACT);
    }
    if typed.chars().count() >= 2 && name.starts_with(&typed) {
        return Some(PREFIX);
    }
    let words: Vec<&str> = name.split(' ').collect();
    let inside = |w: &str| {
        words.iter().any(|n| n.starts_with(w)) || (w.chars().count() >= 3 && name.contains(w))
    };
    if typed.split(' ').all(inside) {
        return Some(ALL_WORDS);
    }
    typed
        .split(' ')
        .any(|w| words.contains(&w))
        .then_some(SOME_WORD)
}

/// Every item `typed` names, the surest first; between equals, in the
/// order given (so a world's own order, what you watch first, decides).
pub fn rank<'a, T>(typed: &str, items: &'a [T], name: impl Fn(&T) -> &str) -> Vec<(&'a T, f64)> {
    let mut out: Vec<(&T, f64)> = items
        .iter()
        .filter_map(|item| score(typed, name(item)).map(|s| (item, s)))
        .collect();
    out.sort_by(|a, b| b.1.total_cmp(&a.1));
    out
}

/// The item `typed` names best, and how sure that is.
pub fn best<'a, T>(typed: &str, items: &'a [T], name: impl Fn(&T) -> &str) -> Option<(&'a T, f64)> {
    rank(typed, items, name).into_iter().next()
}

/// A name's sure after a verb: at most the verb's.
pub fn after_verb(sure: f64) -> f64 {
    sure.min(VERB)
}

/// What [`pick_by_name_or_next_open`] found.
#[derive(Debug, PartialEq)]
pub enum Pick<'a, T> {
    /// This one.
    One(&'a T),
    /// Nothing by the name asked for.
    NoSuch(String),
    /// None was named, and every one is done.
    AllDone,
    /// There are none at all.
    Empty,
}

/// The one asked for, by its id or its name (any case), or with none
/// named the first still open: `--do tick [habit]`, `--do tick [ritual]`.
pub fn pick_by_name_or_next_open<'a, T>(
    items: &'a [T],
    wanted: Option<&str>,
    id: impl Fn(&T) -> &str,
    name: impl Fn(&T) -> &str,
    open: impl Fn(&T) -> bool,
) -> Pick<'a, T> {
    match wanted.map(str::trim).filter(|w| !w.is_empty()) {
        Some(w) => items
            .iter()
            .find(|i| id(i) == w || name(i).eq_ignore_ascii_case(w))
            .map_or_else(|| Pick::NoSuch(w.to_owned()), Pick::One),
        None if items.is_empty() => Pick::Empty,
        None => items
            .iter()
            .find(|i| open(i))
            .map_or(Pick::AllDone, Pick::One),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn one_scale_for_every_world() {
        assert_eq!(score("Read", "read"), Some(EXACT));
        assert_eq!(score("  night   drive ", "Night Drive"), Some(EXACT));
        assert_eq!(score("walk", "Walk outside"), Some(PREFIX));
        assert_eq!(score("outside", "Walk outside"), Some(ALL_WORDS));
        assert_eq!(score("drive night", "Night Drive"), Some(ALL_WORDS));
        assert_eq!(score("ieren", "Frieren"), Some(ALL_WORDS));
        assert_eq!(score("walk the dog", "Walk"), Some(SOME_WORD));
        assert_eq!(score("ea", "Read"), None, "two letters must start a word");
        assert_eq!(score("dance", "Walk outside"), None);
        assert_eq!(score("", "Walk"), None);
        // The order the scale promises, from the surest down.
        let scale = [EXACT, VERB, PREFIX, ALL_WORDS, SOME_WORD, GUESS];
        assert!(scale.windows(2).all(|w| w[0] > w[1]));
        assert_eq!(after_verb(EXACT), VERB);
        assert_eq!(after_verb(PREFIX), PREFIX);
    }

    #[test]
    fn the_surest_name_wins_and_equals_keep_their_order() {
        let names = ["Kaito Mori", "Kaito", "Night Drive", "Kaito Mori live"];
        let got = rank("kaito", &names, |n| n);
        let order: Vec<_> = got.iter().map(|(n, _)| **n).collect();
        assert_eq!(order, ["Kaito", "Kaito Mori", "Kaito Mori live"]);
        assert_eq!(best("kaito m", &names, |n| n), Some((&names[0], PREFIX)));
        assert_eq!(best("jazz", &names, |n| n), None);
    }

    #[test]
    fn picks_by_id_or_name_else_the_next_open() {
        struct H(&'static str, &'static str, bool);
        let all = [H("walk", "Walk", true), H("read", "Read", false)];
        let pick = |w| pick_by_name_or_next_open(&all, w, |h| h.0, |h| h.1, |h| !h.2);
        assert!(matches!(pick(Some("READ")), Pick::One(h) if h.0 == "read"));
        assert!(matches!(pick(Some("walk")), Pick::One(h) if h.0 == "walk"));
        assert!(matches!(pick(None), Pick::One(h) if h.0 == "read"));
        assert!(matches!(pick(Some(" ")), Pick::One(h) if h.0 == "read"));
        assert!(matches!(pick(Some("dance")), Pick::NoSuch(w) if w == "dance"));
        let done = [H("walk", "Walk", true)];
        assert!(matches!(
            pick_by_name_or_next_open(&done, None, |h| h.0, |h| h.1, |h| !h.2),
            Pick::AllDone
        ));
        let none: [H; 0] = [];
        assert!(matches!(
            pick_by_name_or_next_open(&none, None, |h| h.0, |h| h.1, |h| !h.2),
            Pick::Empty
        ));
    }
}
