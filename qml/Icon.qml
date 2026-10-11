import QtQuick
import QtQuick.Shapes

/*
    The line glyphs, drawn as hairlines in the current colour and sized by
    `size` (the box, in pixels; the stroke stays `stroke` wide at any size).
    The chrome's own few sit on a 14-unit grid; the rest are Lucide's
    (lucide.dev, ISC licence, see CREDITS.md) on their 24-unit grid, drawn
    thinner than Lucide's own so they sit with the hairlines. 12 in a
    button, 16 in the sidebar and the menus, 32 or more for an empty page.

    The chrome's: `arrow-left`, `arrow-right`, `arrow-up-right`, `close`
    (also `x`), `tick` (also `check`), `chevron-down`, `search`, `plus`,
    `minus`, `play`, `sound`.

    Places and pages: `home`, `sun` (today), `sunrise`, `moon`, `bed`,
    `calendar`, `days` (a month of days), `week`, `grid`, `clock`,
    `history`, `timeline`, `chart` (figures), `trend`, `activity` (a
    rhythm), `settings`.

    Writing and learning: `book`, `book-open` (a dictionary), `diary`, `pen`
    (write), `edit`, `cards` (a review), `layers` (decks), `languages`
    (kana), `mic` (a voice), `flame` (a streak), `target`, `checklist`
    (habits), `smile` (a mood), `tag`.

    Watching and listening: `library`, `compass` (discover), `telescope`,
    `sparkles` (a season, what is new), `star` (picks), `heart`
    (favourites), `bookmark`, `eye` (watched), `orbit` (a galaxy), `film`,
    `tv`, `music`, `disc` (an album), `user` (an artist), `list`,
    `playlist`, `queue`, `radio`, `antenna` (stations).

    Actions: `pause`, `skip`, `skip-back`, `shuffle`, `repeat`, `volume`,
    `mute`, `download` (export), `upload` (import), `refresh`, `trash`,
    `more`, `link`, `external` (opens elsewhere), `info`, `alert`.

        Icon { name: "settings"; size: 16; color: Theme.textQuiet }
*/
Shape {
    id: root

    property string name: "close"
    property color color: Theme.text
    property real stroke: 1.2
    property int size: 12
    /** The grid its glyph is drawn on: 14 for the chrome's own, 24 for Lucide's. */
    readonly property int grid: root.paths[root.name] !== undefined ? 14 : 24

    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    readonly property var paths: ({
        "arrow-left": "M 8 2 L 3 7 L 8 12 M 3 7 L 13 7",
        "arrow-right": "M 6 2 L 11 7 L 6 12 M 11 7 L 1 7",
        "arrow-up-right": "M 3 11 L 11 3 M 4 3 L 11 3 L 11 10",
        "close": "M 2 2 L 12 12 M 12 2 L 2 12",
        "x": "M 2 2 L 12 12 M 12 2 L 2 12",
        "tick": "M 2 7.5 L 5.5 11 L 12 3",
        "check": "M 2 7.5 L 5.5 11 L 12 3",
        "chevron-down": "M 2 5 L 7 10 L 12 5",
        "search": "M 6 1 A 5 5 0 1 0 6 11 A 5 5 0 1 0 6 1 M 9.6 9.6 L 13 13",
        "plus": "M 7 1 L 7 13 M 1 7 L 13 7",
        "minus": "M 1 7 L 13 7",
        "play": "M 4 2 L 12 7 L 4 12 Z",
        "sound": "M 2 5 L 4.5 5 L 8 2 L 8 12 L 4.5 9 L 2 9 Z M 10.5 4.5 A 3.5 3.5 0 0 1 10.5 9.5"
    })

    // Lucide's, on 24 units: circles and boxes written as paths.
    readonly property var lines: ({
        // Places and pages
        "home": "M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8 M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z",
        "sun": "M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0 M12 2v2 M12 20v2 M4.93 4.93 l1.41 1.41 M17.66 17.66 l1.41 1.41 M2 12h2 M20 12h2 M6.34 17.66 l-1.41 1.41 M19.07 4.93 l-1.41 1.41",
        "sunrise": "M12 2v8 M4.93 10.93 l1.41 1.41 M2 18h2 M20 18h2 M19.07 10.93 l-1.41 1.41 M22 22H2 M8 6 l4-4 4 4 M16 18a4 4 0 0 0-8 0",
        "moon": "M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 0 0 0 8.268 8.268c.344-.215.825-.004.803.401",
        "bed": "M2 4v16 M2 8h18a2 2 0 0 1 2 2v10 M2 17h20 M6 8v9",
        "calendar": "M8 2v3 M16 2v3 M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2z M3 9h18",
        "days": "M8 2v3 M16 2v3 M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2z M3 9h18 M8 13h.01 M12 13h.01 M16 13h.01 M8 17h.01 M12 17h.01 M16 17h.01",
        "week": "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2z M16 2v3 M3 9h18 M8 2v3 M17 13h-6 M13 17H7 M7 13h.01 M17 17h.01",
        "grid": "M4 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1 -1 1h-5a1 1 0 0 1 -1 -1v-5a1 1 0 0 1 1 -1z M15 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1 -1 1h-5a1 1 0 0 1 -1 -1v-5a1 1 0 0 1 1 -1z M15 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1 -1 1h-5a1 1 0 0 1 -1 -1v-5a1 1 0 0 1 1 -1z M4 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1 -1 1h-5a1 1 0 0 1 -1 -1v-5a1 1 0 0 1 1 -1z",
        "clock": "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0 M12 6v6l4 2",
        "history": "M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8 M3 3v5h5 M12 7v5l4 2",
        "timeline": "M10 6h8 M12 16h6 M3 3v16a2 2 0 0 0 2 2h16 M8 11h7",
        "chart": "M5 21v-6 M12 21V3 M19 21V9",
        "trend": "M16 7h6v6 M22 7 l-8.5 8.5-5-5L2 17",
        "activity": "M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2",
        "settings": "M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915 M9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
        // Writing and learning
        "book": "M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20",
        "book-open": "M12 7v14 M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z",
        "diary": "M13.4 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7.4 M2 6h4 M2 10h4 M2 14h4 M2 18h4 M21.378 5.626a1 1 0 1 0-3.004-3.004l-5.01 5.012a2 2 0 0 0-.506.854l-.837 2.87a.5.5 0 0 0 .62.62l2.87-.837a2 2 0 0 0 .854-.506z",
        "pen": "M13 21h8 M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",
        "edit": "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z M15 5 l4 4",
        "cards": "M4 10c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h4c1.1 0 2 .9 2 2 M10 16c-1.1 0-2-.9-2-2v-4c0-1.1.9-2 2-2h4c1.1 0 2 .9 2 2 M16 14h4a2 2 0 0 1 2 2v4a2 2 0 0 1 -2 2h-4a2 2 0 0 1 -2 -2v-4a2 2 0 0 1 2 -2z",
        "layers": "M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83z M2 12a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 12 M2 17a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 17",
        "languages": "M5 8 l6 6 M4 14 l6-6 2-3 M2 5h12 M7 2h1 M22 22 l-5-10-5 10 M14 18h6",
        "mic": "M12 19v3 M19 10v2a7 7 0 0 1-14 0v-2 M12 2h0a3 3 0 0 1 3 3v7a3 3 0 0 1 -3 3h0a3 3 0 0 1 -3 -3v-7a3 3 0 0 1 3 -3z",
        "flame": "M12 3q1 4 4 6.5t3 5.5a1 1 0 0 1-14 0 5 5 0 0 1 1-3 1 1 0 0 0 5 0c0-2-1.5-3-1.5-5q0-2 2.5-4",
        "target": "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0 M6 12a6 6 0 1 0 12 0a6 6 0 1 0 -12 0 M10 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
        "checklist": "M13 5h8 M13 12h8 M13 19h8 M3 17 l2 2 4-4 M3 7 l2 2 4-4",
        "smile": "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0 M8 14s1.5 2 4 2 4-2 4-2 M9 9L9.01 9 M15 9L15.01 9",
        "tag": "M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z M7 7.5a0.5 0.5 0 1 0 1 0a0.5 0.5 0 1 0 -1 0",
        // Watching and listening
        "library": "M16 6 l4 14 M12 6v14 M8 8v12 M4 4v16",
        "compass": "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0 M16.24 7.76 l-1.804 5.411a2 2 0 0 1-1.265 1.265L7.76 16.24l1.804-5.411a2 2 0 0 1 1.265-1.265z",
        "telescope": "M10.065 12.493 l-6.18 1.318a.934.934 0 0 1-1.108-.702l-.537-2.15a1.07 1.07 0 0 1 .691-1.265l13.504-4.44 M13.56 11.747 l4.332-.924 M16 21 l-3.105-6.21 M16.485 5.94a2 2 0 0 1 1.455-2.425l1.09-.272a1 1 0 0 1 1.212.727l1.515 6.06a1 1 0 0 1-.727 1.213l-1.09.272a2 2 0 0 1-2.425-1.455z M6.158 8.633 l1.114 4.456 M8 21 l3.105-6.21 M10 13a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
        "sparkles": "M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0-1.594 1.594l-1.051 5.558a1 1 0 0 1-1.966 0l-1.051-5.558a2 2 0 0 0-1.594-1.594l-5.558-1.051a1 1 0 0 1 0-1.966l5.558-1.051a2 2 0 0 0 1.594-1.594z M20 2v4 M22 4h-4 M2 20a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
        "star": "M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z",
        "heart": "M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5",
        "bookmark": "M17 3a2 2 0 0 1 2 2v15a1 1 0 0 1-1.496.868l-4.512-2.578a2 2 0 0 0-1.984 0l-4.512 2.578A1 1 0 0 1 5 20V5a2 2 0 0 1 2-2z",
        "eye": "M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0 M9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
        "orbit": "M20.341 6.484A10 10 0 0 1 10.266 21.85 M3.659 17.516A10 10 0 0 1 13.74 2.152 M9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0 M17 5a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M3 19a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
        "film": "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2z M7 3v18 M3 7.5h4 M3 12h18 M3 16.5h4 M17 3v18 M17 7.5h4 M17 16.5h4",
        "tv": "M17 2 l-5 5-5-5 M4 7h16a2 2 0 0 1 2 2v11a2 2 0 0 1 -2 2h-16a2 2 0 0 1 -2 -2v-11a2 2 0 0 1 2 -2z",
        "music": "M9 18V5l12-2v13 M3 18a3 3 0 1 0 6 0a3 3 0 1 0 -6 0 M15 16a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
        "disc": "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0 M6 12c0-1.7.7-3.2 1.8-4.2 M10 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M18 12c0 1.7-.7 3.2-1.8 4.2",
        "user": "M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2 M8 7a4 4 0 1 0 8 0a4 4 0 1 0 -8 0",
        "list": "M3 5h.01 M3 12h.01 M3 19h.01 M8 5h13 M8 12h13 M8 19h13",
        "playlist": "M16 5H3 M11 12H3 M11 19H3 M21 16V5 M15 16a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
        "queue": "M11 5h10 M11 12h10 M11 19h10 M4 4h1v5 M4 9h2 M6.5 20H3.4c0-1 2.6-1.925 2.6-3.5a1.5 1.5 0 0 0-2.6-1.02",
        "radio": "M16.247 7.761a6 6 0 0 1 0 8.478 M19.075 4.933a10 10 0 0 1 0 14.134 M4.925 19.067a10 10 0 0 1 0-14.134 M7.753 16.239a6 6 0 0 1 0-8.478 M10 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0",
        "antenna": "M4.9 16.1C1 12.2 1 5.8 4.9 1.9 M7.8 4.7a6.14 6.14 0 0 0-.8 7.5 M10 9a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M16.2 4.8c2 2 2.26 5.11.8 7.47 M19.1 1.9a9.96 9.96 0 0 1 0 14.1 M9.5 18h5 M8 22 l4-11 4 11",
        // Actions
        "pause": "M15 3h3a1 1 0 0 1 1 1v16a1 1 0 0 1 -1 1h-3a1 1 0 0 1 -1 -1v-16a1 1 0 0 1 1 -1z M6 3h3a1 1 0 0 1 1 1v16a1 1 0 0 1 -1 1h-3a1 1 0 0 1 -1 -1v-16a1 1 0 0 1 1 -1z",
        "skip": "M21 4v16 M6.029 4.285A2 2 0 0 0 3 6v12a2 2 0 0 0 3.029 1.715l9.997-5.998a2 2 0 0 0 .003-3.432z",
        "skip-back": "M17.971 4.285A2 2 0 0 1 21 6v12a2 2 0 0 1-3.029 1.715l-9.997-5.998a2 2 0 0 1-.003-3.432z M3 20V4",
        "shuffle": "M18 14 l4 4-4 4 M18 2 l4 4-4 4 M2 18h1.973a4 4 0 0 0 3.3-1.7l5.454-8.6a4 4 0 0 1 3.3-1.7H22 M2 6h1.972a4 4 0 0 1 3.6 2.2 M22 18h-6.041a4 4 0 0 1-3.3-1.8l-.359-.45",
        "repeat": "M17 2 l4 4-4 4 M3 11v-1a4 4 0 0 1 4-4h14 M7 22 l-4-4 4-4 M21 13v1a4 4 0 0 1-4 4H3",
        "volume": "M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z M16 9a5 5 0 0 1 0 6 M19.364 18.364a9 9 0 0 0 0-12.728",
        "mute": "M11 4.702a.7.7 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.7.7 0 0 0 11 19.298z M16.5 14.5 l5-5 M16.5 9.5 l5 5",
        "download": "M12 15V3 M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4 M7 10 l5 5 5-5",
        "upload": "M12 3v12 M17 8 l-5-5-5 5 M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4",
        "refresh": "M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8 M21 3v5h-5 M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16 M8 16H3v5",
        "trash": "M3 6h18 M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6 M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2 M10 11L10 17 M14 11L14 17",
        "more": "M11 12a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M18 12a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M4 12a1 1 0 1 0 2 0a1 1 0 1 0 -2 0",
        "link": "M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71 M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71",
        "external": "M15 3h6v6 M10 14 21 3 M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6",
        "info": "M2 12a10 10 0 1 0 20 0a10 10 0 1 0 -20 0 M12 16v-4 M12 8h.01",
        "alert": "M21.73 18 l-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3 M12 9v4 M12 17h.01"
    })

    ShapePath {
        strokeColor: root.color
        strokeWidth: root.stroke
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        scale: Qt.size(root.size / root.grid, root.size / root.grid)
        PathSvg { path: root.paths[root.name] || root.lines[root.name] || "" }
    }
}
