pragma Singleton
import QtQuick

/*
    Numbers, days, times and durations as the screens write them. A day is
    a `YYYY-MM-DD` string (as the Rust side sends days); a time is an ISO
    string or a Date. Days are read at noon, so no time zone moves them to
    the day before.

        Format.plural(3, "card")        // 3 cards
        Format.long("2026-10-09")       // Friday 9 October
        Format.when(entry.at)           // today 14:02
        Format.length(album.duration)   // 42 min
*/
QtObject {
    id: format

    // ---- Counts -----------------------------------------------------------------
    /** `1 card`, `3 cards`; `many` for a plural that isn't `one` + s (`1 entry`, `2 entries`). */
    function plural(n, one, many) { return n + " " + (n === 1 ? one : (many || one + "s")) }

    // ---- Days ---------------------------------------------------------------------
    /** A date as the day it falls on here, `2026-10-09`; today when not given. */
    function dayOf(date) {
        const d = date === undefined ? new Date() : new Date(date)
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0")
    }
    /** A `YYYY-MM-DD` day as a date at noon, so no time zone moves it. */
    function toDate(day) { return new Date(day + "T12:00:00") }
    /** The day `n` days after `day` (before it, for a negative `n`), the same way written. */
    function addDays(day, n) {
        const d = toDate(day)
        d.setDate(d.getDate() + n)
        return dayOf(d)
    }

    /** `Thu`. */
    function weekday(day) { return Qt.formatDate(toDate(day), "ddd") }
    /** `9`: the day of the month alone. */
    function dayNumber(day) { return String(toDate(day).getDate()) }
    /** `9 Oct`. */
    function short(day) { return Qt.formatDate(toDate(day), "d MMM") }
    /**
        `Thursday 9 October`. `year`: false (the default) leaves the year
        out, true always writes it (`Thursday 9 October 2026`), `"other"`
        only when it isn't this year.
    */
    function long(day, year) {
        const d = toDate(day)
        const withYear = year === true || (year === "other" && d.getFullYear() !== new Date().getFullYear())
        return Qt.formatDate(d, withYear ? "dddd d MMMM yyyy" : "dddd d MMMM")
    }
    /** `October 2026`. */
    function month(day) { return Qt.formatDate(toDate(day), "MMMM yyyy") }
    /** `9 October 2026`, for a time (an ISO string or a Date). */
    function date(time) { return Qt.formatDate(new Date(time), "d MMMM yyyy") }

    // ---- Times, from now -------------------------------------------------------
    /**
        A time as words, `never` for none. `style`:
        - `"week"` (the default): `today 14:02`, `Tue 09:10` within the
          week, `3 Mar`, `3 Mar 2025` once it's most of a year ago;
        - `"yesterday"`: `Today, 21:14`, `Yesterday, 09:02`, `3 Oct`,
          counting calendar days.
    */
    function when(time, style) {
        if (!time) return "never"
        const t = new Date(time)
        if (isNaN(t.getTime())) return "never"
        const now = new Date()
        const clock = Qt.formatTime(t, "HH:mm")
        if (style === "yesterday") {
            const startOf = d => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
            const days = Math.round((startOf(now) - startOf(t)) / 86400000)
            if (days === 0) return "Today, " + clock
            if (days === 1) return "Yesterday, " + clock
            return Qt.formatDate(t, "d MMM")
        }
        if (t.toDateString() === now.toDateString()) return "today " + clock
        const days = (now.getTime() - t.getTime()) / 86400000
        if (days < 6) return Qt.formatDate(t, "ddd") + " " + clock
        return Qt.formatDate(t, days > 300 ? "d MMM yyyy" : "d MMM")
    }
    readonly property var monthsShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    /** How long ago, in whole days: `today`, `yesterday`, `3 days ago`, `May 2024`, then `2023`. */
    function ago(time) {
        const d = new Date(time)
        const days = Math.floor((Date.now() - d.getTime()) / 86400000)
        if (days <= 0) return "today"
        if (days === 1) return "yesterday"
        if (days < 30) return days + " days ago"
        if (days < 365) return monthsShort[d.getMonth()] + " " + d.getFullYear()
        return String(d.getFullYear())
    }
    /** How long until a unix time (seconds): `in 35 min`, `in 5 h`, `tomorrow`, `in 3 days`, `out now` once it's past. */
    function until(at) {
        const s = at - Date.now() / 1000
        if (s <= 0) return "out now"
        const h = s / 3600
        if (h < 1) return "in " + Math.max(1, Math.round(s / 60)) + " min"
        if (h < 24) return "in " + Math.round(h) + " h"
        const d = Math.round(h / 24)
        return d === 1 ? "tomorrow" : "in " + d + " days"
    }

    // ---- Durations ----------------------------------------------------------------
    /** Hours as a figure, to a quarter when it is one: `7 h`, `7.5 h`, `7.25 h`, else `7.3 h`. */
    function hours(h) {
        return (Number.isInteger(h * 4) ? String(Math.round(h * 4) / 4) : h.toFixed(1)) + " h"
    }
    /** Minutes as hours and minutes, short: `7 h 10 m`, `8 h`, `45 m`. */
    function hm(minutes) {
        const h = Math.floor(minutes / 60)
        const m = Math.round(minutes % 60)
        if (h === 0) return m + " m"
        if (m === 0) return h + " h"
        return h + " h " + m + " m"
    }
    /** A length in seconds, to the minute: `42 min`, `3 h 10 min`, `2 h 0 min`; `empty` (a dash unless given) for none. */
    function length(seconds, empty) {
        if (!seconds) return empty === undefined ? "–" : empty
        const m = Math.round(seconds / 60)
        return m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min"
    }
    /** Like `length`, with seconds under a minute: `40 s`, `4 min`, `1 h 12 min`. */
    function duration(seconds) {
        if (seconds < 60) return seconds + " s"
        return length(seconds)
    }
    /** A total of minutes, rounder as it grows: `40 min`, `3 h 20 min`, `5 h`, and from 10 hours on the hours alone (`41 h`). */
    function total(minutes) {
        if (minutes < 60) return minutes + " min"
        const h = Math.floor(minutes / 60), m = minutes % 60
        return h >= 10 || !m ? h + " h" : h + " h " + m + " min"
    }
    /** Where a track is, or how long it is: `3:07`, `1:02:45`; a dash for none. */
    function timer(seconds) {
        if (seconds === null || seconds === undefined || !isFinite(seconds)) return "–"
        const s = Math.max(0, Math.floor(seconds))
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = String(s % 60).padStart(2, "0")
        return h ? h + ":" + String(m).padStart(2, "0") + ":" + r : m + ":" + r
    }
    /** Minutes past midnight as a time of day, past midnight too: 1470 is `00:30`. */
    function timeOfDay(minutes) {
        const m = ((Math.round(minutes) % 1440) + 1440) % 1440
        return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0")
    }
}
