# sol-quick

**The Sol design language as a Qt Quick module, and the Rust side every
world app shares.** A world's desktop app is a Cargo binary: its own logic
in Rust on [Orbit](../orbit)'s `Link`, its screens in QML built from this
crate's `Sol.Design` module, and the window, the connection to Sol,
installing and updating all from `sol_quick::run`. No webview, no Node: the
screens are drawn by Qt's scene graph with real blur, shaders and glows.

How a world app is laid out and what it uses from here is in
[docs/world-apps.md](docs/world-apps.md); working on the kit itself, in
[CLAUDE.md](CLAUDE.md).

## Using it

Two crates under one tag: `sol-quick` (this folder: the QML module, the
window, `run`) and `sol-quick-core` (`core/`: everything that needs no Qt,
which `sol-quick` re-exports under the same paths). A world's app depends
on the first; its logic, in a crate of its own, on the second alone, under
the name `sol-quick`, so the paths are the same and its tests never build
Qt:

```toml
# Cargo.toml (the app)
[dependencies]
terra-core = { path = "crates/terra-core" }
sol-quick = { git = "https://github.com/Draysh/sol-quick", tag = "v1.1.0" }   # or path = "../../kit/quick" (worlds.sh use-local)
cxx-qt = "0.10"
[build-dependencies]
cxx-qt-build = { version = "0.10", features = ["link_qt_object_files"] }

# crates/terra-core/Cargo.toml (the logic, and every test)
[dependencies]
sol-quick = { package = "sol-quick-core", git = "https://github.com/Draysh/sol-quick", tag = "v1.1.0" }   # or path = "../../../../kit/quick/core"
```

The test helpers (`sol_quick::testing`) are always there: no feature, so
the kit is one build for an app and its tests.

`build.rs` declares the app's own QML module (`Sol.<Name>`, every file in
`qml/`), and `main.rs` hands `sol_quick::run` a `World`: the manifest, the
update key, the icons, the `Handler` for what Sol asks of the app, the
`Commands` its screens call, the URL of `Main.qml`, and `source:
env!("CARGO_MANIFEST_DIR")` (where a preview with `SOL_QML_LIVE=1` reads
the screens from). The template in
`kit/template` is the smallest complete example; `cargo build` compiles the
QML too, so a mistake in a `.qml` file fails the build.

Needs Qt 6.12 or later: `qt6-base`, `qt6-declarative`, `qt6-shadertools`
and `qt6-multimedia` (the kit's own sounds use it, so every world does).

## The Rust side

What needs Qt is in `src/` (the crate `sol-quick`); the rest is in
`core/src/` (`sol-quick-core`), and `src/lib.rs` re-exports all of it, so
`sol_quick::desktop`, `sol_quick::testing` and the rest name the same
things from either crate.

| File | What it does |
| --- | --- |
| `src/lib.rs` | `pub use sol_quick_core::*`, `run`, `bridge`; core's `lib.rs` re-exports `World`, `Prepare`, `Sample`, `Commands`, `say`, `data_dir`, `cache_dir`, `device_name`, `emit`, `open`, `quit`, `leave`, `runtime`, `Shared`, `handler` |
| `src/app/` | `run` in `start.rs`, a function for each step (command line, the log, one copy at a time, an update on trial, SIGTERM/SIGINT, the tokio runtime, the `Link`, moons, the tray, then the window); `World`, `Runtime`, `data_dir`, `cache_dir`, `emit`, `quit`, `leave` are `core/src/app.rs` |
| `src/live.rs` (+ `cpp/live.h`) | `SOL_QML_LIVE`: a preview reads the QML modules from their checkouts (a URL interceptor on the engine) |
| `src/bridge.rs` | `SolBackend`, the one QObject the QML side talks to (properties, `call`, signals) |

In `core/src/`:

| File | What it does |
| --- | --- |
| `shared.rs` | The commands every world's screens can call besides their own (below) |
| `exchange.rs` | Export and import of a world's own collections (those in its manifest) as one JSON file: `export`, `write`, `read`, `plan`, `import`; an import goes through the `Link`, merges by id and deletes nothing |
| `seen.rs` | What pages last showed (`Sol.callSeen`), a file per key in the data folder's `seen/`, pruned after 30 days |
| `autostart.rs` | Starting with the computer: `~/.config/autostart/sol-<world>.desktop` for the installed copy, run with `--login` (an entry from before 1.0 with `--background` is brought up to date) |
| `commands.rs` | `Commands` (typed async commands by name; replies go to JSON text, so an `f32` stays as written) and `say` (an error as one sentence with its causes, `{:#}`) |
| `engine.rs` | `Shared<T>` (a world's engine, built in `prepare` and read by commands and the handler) and `handler(|| …)` (a `Handler` made for each call, around that engine) |
| `capture.rs` | Quick capture (`docs/world-apps.md`, "Quick capture"): every running world asked, best offer first (`Line`, `Offer`) |
| `desktop/mod.rs` | The desktop around the app (`docs/world-apps.md`): `Desktop`, a world's status, actions, find, verbs and questions said once and registered as the door's commands; `Plan`, `Typed`, `encode`; and the portal (`portal.rs`: `notify`, `pick_file`, global shortcuts) |
| `desktop/matching.rs` | Quick capture's one scale of how sure (`EXACT` … `GUESS`), `score`, `best`, `rank`, `after_verb`, `pick_by_name_or_next_open` |
| `door.rs` | What comes through the door: `--do`, `--find` (`Do`, `Query`, `Found`), another world asked (`ask`, `tell`, `Question`, `Unanswered`) |
| `questions.rs` | The questions worlds ask each other, typed (`Furigana`, `Say`, `Level`, `AddWord`, `Now`, `Duck`, `Pause`), and `ask` / `tell` for them |
| `moments.rs` | Moments played once per occasion for the person (`first_time`, kept in the world's `moments` collection) |
| `sky.rs` | The Sky: a world's milestones as constellations (`Constellation`, `Star`, `steps`), lit once each into the world's `sky` collection (`record`, `lit`, `show`, `view`, the layout), comets (`comet_on`, `comet`, `catch_comet`) and the real sky (`events_on`, `tonight`: full moons, the Perseids, Saturn's opposition) |
| `look_art.rs` | The Yozora look's pictures (`docs/yozora.md` in the workspace): the list of where they come from (`core/yozora-art.json`: TMDB's and AniList's CDNs, no key), `missing`, `list`, and `fetch_missing`, which the window runs in the background at start (two at a time, those hosts only, each written whole) before listing the folder again |
| `kept.rs` | `kept::<T>(&link, "cards")`: a collection read once and kept (shared, `Arc`) until a write or a change from Sol touches it; for commands that each read the same big collection |
| `app.rs` (`Moon`, `Carried`, `emit_in`) | A moon carried in a planet's app: `sol_quick::run_with(world, vec![moon])` runs it in the planet's process with its own link, door, status and commands (the shared ones on its link); `Runtime::world(id)`; `emit_in(world, …)` tells a carried world's pages |
| `commands.rs` | `Commands` (the registry: `add`, `undoable`, `creates`, `names`; over the link, `engine(&ENGINE)` or `over(…)`), `doc`, `say` |
| `undo.rs` | Undo: the documents a write changes, kept under a token (`keep`, `take`) and put back (`restore`) |
| `status.rs` | The status file for the bar (`refresh`) and `--status` |
| `testing.rs` | For a world's tests (always built; nothing in it runs unless a test calls it) (`docs/world-apps.md`, "Tests"): `offline_link`, `assert_manifest` and `Expect`, `capture_q`, `undoably` and `take_back`, `FakeDoor`, and orbit's `FakeHttp`, `Reply`, `StandInSol` |
| `single.rs` | One copy at a time: the abstract socket `sol-<world>:$XDG_RUNTIME_DIR` (`sol-preview-<world>:…` in preview; `sol-test-<pid>-<world>` in any process that isn't `run`, so tests never reach a running app) and its knocks (`show`, `open <path>`, and `ask <command> <json>` for the desktop's `do` and `find`, answered `ok <reply>` or `no <why>`); also the file `sol-<world>.sock` that versions before 1.0 use, knocked on and listened at, so an old and a new version never both run |
| `tray.rs` | One Sol tray for every Sol app here (the first one hosts it; the others join over a socket) and the counts on the apps' icons |
| `navidrome/` | With the `fake-navidrome` feature (of either crate; Neptune and Triton): `FakeNavidrome`, a stand-in Navidrome on 127.0.0.1 for previews and tests (a made-up library with drawn covers, playlists, stars, lyrics (Japanese for Kaito Mori), two artists of anime openings and endings (for Triton), streams of silence; `mod.rs` the server's handle and `preview()`, `library.rs` the library, `api.rs` the Subsonic endpoints, `http.rs` the socket, `media.rs` the PNGs and WAVs) |

**The shared commands** (`shared.rs`): `connect {server}`, `cancel`,
`forget`, `settings`, `open_in_sol`, `doors` (the worlds installed here),
`open_world {world, path?}`, `notify {title, body?, action?: [id, label]}`,
`check_updates`, `install_update`, `set_auto_update {auto}`, `restart`,
`install_app`, `autostart` (null when this copy can't), `set_autostart {on}`;
the writes kept aside (`kept`, `keep_mine {seq}`, `drop_kept {seq}`,
`save_kept`, which writes them to a JSON file in Downloads and returns its
path); `export_world` (every document of the world's own collections to
`Downloads/sol-<world>-<stamp>.json`, a preview's `downloads/` instead; replies `{ path, documents }`) and
`moment {occasion}` (true the first time, for the person: recorded in the
world's `moments`), `comet` (today's comet day, or null), `catch_comet
{day}` (its star in the Sky), `sky_tonight` (the real sky's events for
this world today, each lit as a star once), `undoable {command, args}` (the world's write run
with the documents it touches kept: `{ result, undo }`, `undo` a token or
null) and `restore {undo}` (Undo: those documents put back as they were;
the world's own collections only), `capture {line, world?}` (quick capture: every running world's
offer, best first, and `away`, those not running; with `world`, that one
does it); `import_world {path, dry?}` (an export file read back: with `dry`, what it
would do; without, the same written through the link; replies a plan,
`{ world, exported_at, added, replaced, same, skipped, collections: [{
collection, label, added, replaced, same }] }`), `pick_file {title, filter?:
{label, globs}}` (a file from the desktop's picker, the portal: its path,
null when closed, an error where there is no portal); and `start_fresh` when the
local copy didn't open. They are added
after the world's own, so a world command with one of these names is
replaced: don't use them.

**Environment** (the review hooks and switches):

| Variable | What it does |
| --- | --- |
| `SOL_PREVIEW` | The Shell without pairing, on a throwaway copy (`/tmp/sol-preview-<world>`) filled with sample data the first time; its own socket, so it runs beside the installed app. On with any value, even `0` |
| `SOL_SHOT=<png>` | A picture of the window once its page is ready (below), then the app quits; so a fresh preview copy, filled with its sample data first, shoots the same page. Beside `SOL_DRIVE` it doesn't quit (the drive ends the run; a drive that quits sooner leaves no picture) |
| `SOL_SHOT_PATH=/page?key=v` | The page to open first, with its params; keys starting with `_` stage the picture: `_notice=1` (a notice), `_ask=1` (the dialog), `_notify=1` (a desktop notification), `_palette=1` (the command palette; `_palette=rate` with that typed), `_scroll=N` (the page scrolled to N, or `end`, once it has settled; held to the page's end), `_notice=button` (a notice with a button), `_kept=1` (`KeptAside` with sample rows), `_capture=<line>` (quick capture open with the line typed; its own picture is saved beside as `<shot>-capture.png`), `_problem=newer\|damaged` (the window's "copy won't open" view instead of the Shell), `_tour=N` (the first-run tour open at card N), `_moment=<name>[:<arg>]` (one of the window's `moments`, played without its occasion, taken 60% through; `_moment=star`, the kit's own: a star lighting), `_comet=1` (a comet held mid-way across the Sheet), `_sky=full-moon\|perseids\|opposition` (that night of the real sky on the Sheet), `_hour=N` (the hour the navigator keeps: sleepy from 23 to 5), `_after=<ms>` (not sooner than that, for what the ready rule can't see) |
| `SOL_SHOTS=<list>` | Many pictures in one run, one after another, then the app quits: `<png>=<path?keys>` each (as `SOL_SHOT` and `SOL_SHOT_PATH`), a line or `;` apart, or the name of a file holding them (`#` starts a comment). Each opens its page, scrolls, stages its keys, waits until ready and is taken; what the one before staged (dialogs, the palette, notices, a moment, quick capture) is put away first. `scripts/shots.sh` runs a world with a list on a hidden display. A `_problem` picture goes first (the Shell then loads for the rest); a world's own keys that it reads once at start (Neptune's `_vinyl`, Triton's `_dj`) work in the first picture only |
| `SOL_SHOT_AFTER=<ms>` | The most a picture waits for its page to be ready: 8000 unless set; one that times out is taken anyway and says so in the journal (`SOL_SHOT: … wasn't ready`) |
| `SOL_SHOT_READY=0` | The old way: each picture `SOL_SHOT_AFTER` ms in, ready or not |
| `SOL_SHOT_CALM=1` | Pictures without the arrivals: the Theme's durations are 0, so nothing has to settle and a page is ready at once (about 4× faster). Text that never faded in is drawn with coloured edges (sub-pixel), unlike on screen, so use it for layout, not for the last look |
| `SOL_QML_LIVE=1` | A preview reads the kit's and the world's QML from their checkouts, so an edited `.qml` shows without a build (`docs/world-apps.md`, "Live QML"); `scripts/hidden.sh` turns it on unless set, `0` looks at the compiled QML |
| `SOL_FPS` | The frames really painted each second, in the journal (0 while nothing moves). On with any value |
| `SOL_DRIVE=<file.qml>` | A script loaded into the window (handed `win`) that drives it end to end, and ends the run with `Qt.quit()` |
| `SOL_CALM` | This run with less motion (moments short and still), whatever the device's setting says |
| `SOL_FLAVOUR=<world>` | This run wears that world's flavour (`saturn`, `mercury`, `neptune`, `terra`), whichever world the app is (the gallery's pictures of each flavour; `SolBackend.flavour`, read by `Theme.lookWorld`) |
| `SOL_FONTS=<file>:<file>` | Fonts this run adds to the kit's: the gallery is handed the worlds' own title faces with it (`scripts/gallery-shots.sh` does it when the worlds' checkouts sit beside the kit) |
| `SOL_FAKE_NAVIDROME=off` | A music world's preview without the stand-in Navidrome (`navidrome::preview()` answers none), to see its pages unconnected |
| `QT_SCALE_FACTOR` | Qt's own: `1.5` to check fractional scaling; a large one (3) also makes a narrow window |

## The QML module (`qml/`, `Sol.Design`)

Every `.qml` file in `qml/` is registered (no `qmldir`); one whose leading
lines include `pragma Singleton` is a singleton. `import Sol.Design` in a
world's files; inside the kit and in a world, `import Sol.Design as Design`
for `Design.Screen` (Qt has a `Screen` of its own).

**Singletons**

- `Theme`: every token (the sky in three depths, the flavour's colours,
  type, spacing, corners, durations and curves: "Motion" below) and the rules the controls share:
  `calm` (less motion, per device: Settings → On this device, or `SOL_CALM`),
  `whenSeen(item, arrival)`, `flickableOf(item)`, `scrollWith(item, view)`
  (what LongGrid is built on), `wheel(event, notch)`, `screenOf(item)`,
  `keepInView(flick, top, height)`, `typing(item)`, `isRepeater(item)`,
  `chosenAccent` (this device's accent, `sol.<world>`), `mark(c)`, `tint(c, a)`.
- `Sol`: the connection as the screens see it (`status`, `paired`,
  `online`, `unsent`, `kept`, `keptCount`, `problem`,
  `settingsVersion`, `app`, `manifest`, `preview`, `background`), `call`
  and `callSeen`, and the helpers every
  world shares: `fail`, `same`, `update`, `fill`, `fetch`, `sync`,
  `follow`, `badge`, `openUrl`, `openInSol`, `openWorld`, `doors`, `moons`,
  `clock`, `fileUrl(path)` (a file's address, each part encoded), `undoable(command, args, { title, body, undo?, undone? })` (a
  write with Undo in its notice: the documents the world's Rust says it
  touches are kept and put back, or a way back of its own), and the
  signals `event(name, data)` and `changedIn(collections)` (what `Watch`
  listens to). `callSeen` reads and keeps what a page showed on the Rust
  side, off the window's thread, and hands `use` a third argument, `same`,
  when the fresh reply is what was shown (`fill` then leaves it be).
- `Format`: counts, days, times and durations as words (`plural`, `kanji`
  (a number as a title card writes it, 十七), `dayOf`,
  `toDate`, `addDays`, `weekday`, `dayNumber`, `short`, `long`, `month`,
  `date`, `when`, `ago`, `until`, `hours`, `hm`, `length`, `duration`,
  `total`, `timer`, `timeOfDay`); each documents its output.
- `Worlds`: every world's name, role, tagline, colour, tilt, photo, kin
  (moons and planets), and the real sky (`skyOf`, `moonAt`, `now`).
- `Notices`: in-app notices (`show`, with an optional button: `action`
  and `run`; `dismiss`, `act`, `failed`).
- `Sounds`: `tick` (Button, Chip, Tabs, Select, Toggle and Check tick by themselves), `done` (`Sol.undoable` plays it when a write goes through), `off`, `chime` (a moment's, two soft seconds) and `voice` (the world's own, for its main good moment only: Saturn's soft ring, Neptune's water drop, Mercury's bell, Terra's wood tick, Luna's chime, Titan's whoosh, Triton's static blip; `voiceName` says which; it takes the place of a `done` just played). On by default and low (`level`, 0.5, under each sound's own share), one switch in `DeviceCard` for all; a device that has said keeps what it said.
- `SolBackend` (Rust, `bridge.rs`): what `Sol` and `AppWindow` are built on.

**The frame**

- `AppWindow`: a world app's window: Connect until paired, then the Shell
  with the app's `sections` and `pages`; `menu`, `ask`, `commandPalette`,
  `commands`, `find`, `footer`, `busy`, `warn`, `widget`, `widgetName`, and
  `started()` (the moment to start the app's own work: once paired, at
  once in preview; not again on an offline/online flip), `tour` (the
  first-run tour's three cards, below), and `moments` (the scenes a
  picture can stage with `_moment=<name>`). It keeps a `CarriedMoons` (the
  moons' sections, pages, palette rows, moments and overlays merged with
  the world's) and a `WindowShots` (pictures for review, what their `_`
  keys stage, `SOL_FPS` and `SOL_TRACE`).
- `Shell`: the sidebar and the pane, history and the way back (a page
  opened from another has one, a section opened with params from another
  page too), the keys, the hero flight (`go(path, params, { item, url })`),
  `retab(params)` (the page on screen takes new params in the same step
  of the history: a tab chosen), `sectionOf(path)`, `isSection(path)`,
  `aliases` (paths that moved, still reachable: `AppWindow { aliases: ({
  "/calendar": "/schedule?tab=calendar" }) }`; links, other apps, quick
  capture and `--open` may name the old path, and its params go under the
  ones asked with). A section's tab may be a page of its own: `pages: ({
  "/schedule": calendar, "/schedule?tab=timeline": timeline })`, each with
  the same PageHead `tabs`; choosing a tab puts its page in that step of
  the history (settling in as a section does) and each keeps its scroll.
- `Sidebar` (the Shell's own, with `SidebarRow` for sections and doors).
  A section is `{ path, label, hint, icon?, badge?, children?, tabs? }`:
  its `icon` (an `Icon` name) stands where the small dot would, quiet at
  rest and bright when current or under the pointer, and alone on the
  rail; doors keep their world's glyph. The palette's "Go to" rows lead
  with it too. `children: [{ path, label, hint?, icon? }]` are pages under
  it: one row that opens out to them (a step in) while it or one of them
  is open and folds again otherwise, settling as it goes, as a carried
  moon's group does; Ctrl+1…9 count only the sections, and the palette
  names a child with its section ("Go to Activity · History", a moon's
  rows with the moon: "Go to Titan · History"). `tabs: [{ id, label }]`
  lets the palette reach a section's tabs from anywhere ("Go to Schedule
  · Calendar").
- `Screen`: a page in the pane (`header`, `filter`/`filters`, `hero`,
  `scrollBy`, `wheel(event)`, `notch`, `pageStep`, `actions`: the page's
  own rows in the palette and on the `?` sheet, "Rate 8", "Bury this card").
  Its content starts at the pane's margin and is never wider than
  `maxWidth` (1400): a wider pane leaves the rest on the right to the
  still, after `side` (a column just right of it, above it on a
  narrow pane: a cover, art; `sideAbove: false` leaves it out on a narrow
  pane, for a page that shows the same things in its column there); `sparse` composes a page with little on it
  to the still on a wide pane (its title large and its content in a column under it, one group low
  on the left that scrolls together, the still's figure keeping the rest; written down with the
  flavour's `tategaki` (Mercury's), the title stands beside the column instead); `contentX` and `contentWidth` say
  where the content is (a PageHead lines up with it). A page opened from
  another without a header gets a PageHead with its title and the way back.
- `PageHead`: a working page's toolbar (title, a quiet line, actions, the
  way back, `editable`, `tabs`). With `tabs: [{ id, label, count?, hint? }]`
  and `tab: page.params.tab || ""`, the tabs run along its foot, the one
  that is on drawn over its hairline; choosing one puts it in the page's
  path (`/schedule?tab=calendar`, through `Shell.retab`, no new step), so
  Back, links and the palette reach it. The page reads `current` (the tab
  showing: `tab`, or the first) or `params.tab`; `tabChosen(id)` follows a
  choice, `choose(id)` makes one. A section opened with only its tab (or
  `part`, the part of it to show: `/settings?part=titan`) is still the
  section (no way back), and comes back on the tab it was left on; the
  palette offers the page's other tabs ("Show Timeline"). `feature` holds
  the page's one lead object (an album's cover and name), on the still
  under the band, folding away under it as the page scrolls; with a
  flavour's `letterbox` (Saturn's) it stands between a film's thin black
  bars (`letterbox: false` leaves them off). With the flavour's `torii`
  (Mercury's) its foot is a vermilion rule, a gate's beam and posts under
  its Japanese title (not where tabs run along the foot).
- `Tabs`: uppercase words in a row, one of them on, along a hairline
  (`line`) or as plain choices: `options: [{ value, label, count?, hint?, jp? }]`
  (`jp` before the label),
  `value`, `chosen(value)`; the line slides to the next one (moved and
  scaled, at once with less motion), and a row wider than its room
  scrolls sideways.
- `Sheet`: the band across a world's first screen, pinned and shrinking:
  the title card, what sits under it (moon links, the main action) beside
  two or three `figures: [{ value, label, jp }]` (HeroFigures), a comet on
  its days; compact (about 220 px) in a window under 1300 px wide.
  `HeroFigure`: one big figure, its label and its Japanese tag; the
  number counts up as it comes into view (on from the one before when it
  changes), in the room its value takes.
- `Back`: the way back, always 「← 戻る」 BACK, the page it leads to in its
  hint (Space or Enter from the keys).
- `Connect`: pairing; `LinkStatus`: the sidebar's bottom line (what waits
  goes on a line of its own when the whole line doesn't fit its `room`,
  beside the navigator's head chip); `Waiting`:
  a small spinner while the status is unknown.

**Panels**

- `Card` (a raised panel with a title; `menu`: its right-click and a ⋯
  in its head, see Menus below; `span`: 1, 2 or `"row"` of a Grid's
  columns; it settles in with the spring and leans to the pointer;
  `pressable` (or `openable`) gives under a press; `lockOn()` locks its
  brackets on with a few sparks, for a thing that has just gone live), `Grid` (cards in auto-fit columns, row by row; `masonry: true`
  puts each card into the shortest column instead, for pages of cards of
  very different heights: Settings, Today, Taste, Discover; never more
  columns than the cards beside each other need, a card across the whole
  row not counted; `even: true` fills every row it can, four cards two
  and two rather than three and one). A pair (a
  card across two columns beside the cards that fill the rest of its band)
  ends level: the shorter are drawn as tall as the tallest, a Card or
  HudPanel holding its body in the middle of the room (`spare`); cards
  starting on one line whose feet nearly meet (`level`, 128 px and a
  quarter of the taller at most) end level too, their bodies at the top. When a grid
  places its cards again (one grows, hides or shows) they glide to their
  new places (not the first time, not while the width changes, not with
  less motion). `Callout` (a dotted leader and a short list, in a Sheet).
- Lists as long as a library, where only what is in sight is made and the
  page scrolls them like anything else: `LongGrid` (tiles of at least
  `min` across, `tileHeight` tall, on a GridView that uses its tiles again;
  `rows` for whole rows only) and `LongList` (rows each as tall as they
  are). Their delegates are Settles with `animated: list.arrives(index)`,
  so the first screenful settles in. `Sift` sorts and filters the rows for
  them once per change (`rows`, `order`, `text`, `keep`, `words`; the
  typing filtered once it rests), and `shown` is the result.
- `Watch { collections: ["titles", "watched"]; onChanged: page.load() }`:
  a page reads again when documents change in its own collections, here
  or on another device (once a burst; also when every collection may have
  changed; with `settings`, when the settings change in Sol).
- `SettingsScreen`: a world's Settings page as a system menu, its parts
  listed on the left and the chosen one's cards on the right, at the start
  of the pane with a panel no wider than 720 px, a wide window's rest left
  to the still (`/settings?part=<key>`): the kit's `sol`, `export`, `device` and
  `updates`, each carried moon's own, and the world's `SettingsPart`s
  (`key`, `label`, `jp`, `order`, `available`; one with a kit part's key
  takes its place).
- The Settings cards every world has: `SolCard` (with what is kept
  aside), `SettingsCard`, `DeviceCard`, `AppUpdates` (with an update that
  was rolled back), `ExportCard` (export everything to Downloads, import
  a file after saying what it adds and replaces; what goes inside it sits
  below its buttons); `SolCard`, `SettingsCard` and `ExportCard` take
  `world` for a moon the app carries.
- Carried moons: `Moon` (a moon's sections, pages, palette rows, moments
  and overlays, listed in `AppWindow { moons }`), `SolWorld` (one world's
  connection, from `Sol.of(world)` or `Sol.near(item)`: the same members
  as `Sol`), `WorldSettings` (a world's own device settings, in its own
  file), `Screen.world`, `Watch.world`, `PictureStore.world`; `Sol.carried`,
  `callIn`, `callSeenIn`, `fillIn`, `fetchIn`, `undoableIn`, `failIn`,
  `pathOf`, `go`. A `Moon` may declare `settings` (a Component: its cards
  as a part of the planet's Settings page) and `aliases` (its own paths
  that moved); the planet's `SettingsScreen` lists each moon's part
  under its name (`/<moon>/settings` opens it; `MoonSettings` is the
  older column of them, for a page that isn't one), and a moon without a `/sky` page has its sky as a tab
  of the planet's `SkyPage` (`/<moon>/sky`). See `docs/world-apps.md`,
  "Moons".
- `KeptAside`: the writes kept on this device instead of sent (a conflict
  with both copies, a change Sol couldn't take, changes from an earlier
  pairing), with the choice for each and "Save a copy"; the window has one
  (`win.keptAside.open()`) and opens it from its notices.

**Controls**

- `Button` (`primary` once a screen, `ghost`, `quiet`, `round`, `danger`
  for what can't be taken back: the slant outlined in vermilion; a press
  gives and springs back, `pulse()` does it for a press from a key; `icon`
  leads the label with a hairline glyph, for the few actions a glyph makes
  quicker to find, such as Export, Import, Play next, Refresh; `tone`
  marks a ghost or quiet one in a colour, its outline and label: an answer
  picked wrong), `Chip`,
  `Check` (optimistic, `fail()`; `weight` 1–3 rings the box for a streak of 7, 30, 100 days, `weightOf(days)`; `sparks` for a world's main act), `Toggle`, `Slider`, `Field`, `TextArea`
  (`large` for writing at length, `single` when Enter goes on, `ink` and
  `ruled` for writing in ink on a ruled page), `Select`,
  `Editable`, `MoonLink`. `Field` and `Select` sit in a `FieldFrame`, a
  bracketed well lit in the world's light under the pointer and with the
  keys (`bare` leaves it out, for the palette).
- `Key`: a key for one page (quiet while you type, or while a menu, dialog
  or the palette is open).

**Overlays** (on the window, over the pages, on glass)

- `ContextMenu` (one per window: `win.menu`), `CommandPalette` (Ctrl+K)
  (an entry or command may lead with an `icon`, for common actions; a
  menu's other labels line up after it; an entry with `items`, a list or
  a function returning one, nests: one "Rate…" with its numbers inside,
  which the palette shows as one row that opens its own list),
  `Ask` (`win.ask.name(…)`, `win.ask.confirm(…)`), `Hint`, `Notice` (made
  by the window from `Notices.list`), `Shortcuts` (`?`: the Shell's keys,
  the app's, and the palette's actions here, the window's and the page's).
- `MenuArea` (a thing's right-click, laid over its row) and `MoreButton`
  (the ⋯ that opens the same menu under itself): see Menus below.
- `Moment` (one per window, `win.moment.play({ occasion, scene, facts,
  chime, length, hud, ground })`) and `MomentCaption`, a scene's words
  (`jp`, `subtitleJp` and `subtitle`); `Tour` (one per
  window, `win.tourSheet`, filled from `AppWindow.tour`): both in
  `docs/world-apps.md` ("Moments", "The first run").
- `SkyPage` (a world's `/sky`: the map and a card per constellation, from
  the world's `sky` command; in an app that carries moons without a Sky of
  their own, a tab per world, `/sky?tab=titan`, each from its own `sky`), `SkyMap` (the sky drawn, to wander and
  zoom), `StarField` (what every star map stands on, the Sky's, Mercury's
  path and Titan's galaxy: the night and its dust, the view (`cx`, `cy`,
  `zoom`, `px`/`py`, `sx`/`sy`, `panBy`, `zoomAt`, `flyTo`, `home`), drag,
  wheel, pinch and picking a star; the map's own stars, lines and names
  are its children, on a plane that pans as one, and are named again on
  `place()`, never every frame) with `StarLight` (a star's glow and cross,
  one small shader), `StarArc` (how far along, round a star) and
  `StarLine`, `StarScene` (the moment a star lights, played by the window on
  `sky.lit`) and `Comet` (across every Sheet's sky and Saturn's Home, on its few days a year):
  `docs/world-apps.md` ("The Sky").
- `Glass` (the pages behind, blurred and bent; `from` blurs another item,
  as pairing does) and `GlassPanel` (glass with a hairline: what the
  overlays sit on).
- **Yozora (夜空)**, the look of every app (`../../docs/yozora.md` is its
  spec and how it is built): an anime film's night over every page of
  every world. The Theme's tokens take the world's flavour (`Theme.hud`,
  from `yozoraOf(world)`: Saturn's dusk, Mercury's shrine, Neptune's neon,
  Terra's noon; a moon wears its planet's unless it has its own, as Luna's
  evening does on her pages; `SOL_FLAVOUR` wears another),
  corners are square, panels cut one corner at 45° (`Theme.hudCut`), there
  is no day, and capitals are set in the HUD face (`Theme.fontCaps`) for
  labels of one to three words, so the kit's components follow by
  themselves. Titles and Japanese tags are in the flavour's own title face
  (`Theme.fontTitle`, drawn in `Theme.weightTitle`: Corporate Logo for
  Saturn, Yuji Syuku for Mercury, Makinas 4 for Neptune, Keifont for Terra
  and Luna), subtitles and big figures in Corporate Logo
  (`Theme.fontDisplay`). The
  Shell lays `DuskGround` under everything (the page's `Screen.ground`, or
  one of the world's stills turned over by section, `Theme.groundsOf`, a
  moon's own when it has some, `Theme.ownGroundsOf`, graded, the shade
  deeper round the title on a bright flavour, its `pool`, framed by its
  `frame` so the still's subject stands clear of a first page's title;
  without a still, the world's drawn sky) and blurs it once
  (`Shell.groundBlur`); every `HudGlass` (Card, HudPanel, PageHead, the
  rail, the footer, the Sky's night) reads the part under it, with the
  flavour's motif drawn in the same shader (`hud.frag`: Mercury's waves,
  Neptune's neon edge and scanlines, Terra's daylight), with a 1 px
  highlight along its top edge and cut corner, a faint sheen from the top
  and a tint laid thinner at the top than at the foot over art. Overlays
  (GlassPanel) blur the pages live. The rail is numbered, a section's `jp`
  before its name; PageHead, Card, HudPanel and Sheet take a `jp` (the
  title in Japanese) and head with `HudLabel` (HUD capitals, a Japanese
  tag, the flavour's mark: a diamond, a `HudSeal`, neon slashes, a furin;
  Neptune's sets the `jp` first as a lit sign instead); the Sheet is a
  title card: a HUD line (`hud`, `hudJp`), the Japanese title (`jp`), the
  English callout line under it, what sits under that, facts on glass, and
  `vertical` for a line written down the right. Neptune's flavour
  adds rain and a neon glow to the ground (the flavour's `rain` and
  `haze`) and `HudGlitch`, which Screen plays as a page arrives: a scan
  line and a few torn bands for a quarter of a second. The primary Button is a parallelogram
  (as `AngledButton`), a round one a diamond, Progress is `SlantTicks`,
  chips are pills, Display's figures are in the HUD face. `Card` is glass
  with brackets (its glass is made once the card has come into view),
  `HudPanel` likewise; `Empty` is the world's navigator, large, saying its
  line in a bubble (the glyph in a diamond without the portrait, and in a
  card). `Navigator` (in the rail's foot) is the world's character: its
  portrait (`NavigatorFace`) in a cut frame breaking the rail's edge,
  growing into the room the rows leave, and over it a manga bubble
  (`Speech`) with the page's `Screen.sayJp` and `say` typed in, a greeting
  on the first page, or nothing; where there is no room, a head chip on
  the rail's edge whose bubble opens on hover or a click. It hops when a
  line arrives, leans towards a new page, cheers on `Sol.cheer()` and is
  sleepy late at night (`_hour=N` stages the hour). A `Moment` is a film's scene:
  the page's still darkened behind it, black bars, a HUD line, and
  MomentCaption as its title card and subtitles. HudGlass's motif
  `"washi"` (with a paper `tint`) is a sheet of paper: fibres and a faint
  asanoha lattice. `HudSeal` (`round`, `tilt`) is a seal or a stamp
  card's round stamp. The pictures live outside
  every repository (`~/.local/share/sol-yozora/`, fetched by
  `scripts/yozora-art.sh`; the bridge always lists them, `SolBackend.lookArt`);
  the look draws its own skies and leaves the navigator out without them.
  The Sky's night (`StarField`: SkyMap, Mercury's PathMap, Titan's
  GalaxyMap) is no glass: the still itself under a light gradient of the
  ground, so the constellations float on the film.

**Display**

- `Empty` (a page or card with nothing in it yet: the navigator saying
  `jp` and `line`, a `hint`, at most one `action`; `compact` in a card;
  how to word it in `docs/world-apps.md`).
- `NavigatorFace` (the navigator's portrait, cropped and read at its drawn
  size, with the world's motif round it; `diamond` for the head chip;
  `bob()`, `lean()`, `cheer()`), `Speech` (its manga bubble: `jp`, `line`,
  `tail`, `tailAt`, `large`; typed in as the words change, whole at once
  in a picture; a line that wraps is balanced, the Japanese broken after
  its 、 when that leaves two lines that fit, so nothing stands alone on
  the last line).
- `NeonSign` (a word in katakana written down in a lit tube, glowing on a
  dark board: `text`, `light`, `size`, `room`; drawn once, never moving),
  `ChromaText` (a Text whose big words split their colours at the edges,
  red one side and cyan the other, with the flavour's `chroma`; a plain
  Text otherwise). The neon flavour's `signs` makes a Sheet's `vertical` a
  NeonSign; its `chroma` edges the Sheet's title and a sparse page's big
  title.
- `Display` (a figure that counts up), `DataRows` (`Label: value`; `ledger`: a line
  each across the width, the value at its right end, hairlines between, as
  Settings' cards are),
  `Progress`, `Chart`, `Skeleton` (a page's shape before its data).
- `Picture` (a picture from a `url`, or a `key` in a `PictureStore`:
  `ratio`, `crop`, `outline`, `lift`/`hovered`, `dim`, `animated`, a fade,
  a retry when a file has gone, `radius`; without a picture, a card in the
  world's colours with one kanji or katakana on it, `glyph`, else chosen by
  `name` or `seed`), `PictureStore` (a
  world's pictures fetched once to disk by one of its commands), `Poster`
  (a Picture for a network cover, 2:3, outlined).
- `Strip`: a row that scrolls sideways (sideways wheel, swipe or Shift;
  the vertical wheel goes to the page), a hairline showing where you are,
  `fades` at the ends.
- `Body` (a world's photo on a sphere lit by a shader: its place in the photo, `fit`, and its `air` are in `Worlds`; `green` and `cloudy` shape a world with clouds, set for every body of a world by `Worlds.setSurface` (Terra's habits and weather); `pace` speeds its clouds), `Reticle`, `WorldGlyph`,
  `Icon` (below), `Tone` (a picture's colour), `Spark` (a burst for a moment that
  earns one), `Rings` (faint rings round a body, its far half hidden behind it, drawn once: Mercury's weeks, Saturn's lit rings).
- Text: `Heading`, `Label` (uppercase, small, bright), `Quiet` (uppercase,
  small, quiet), `Words` (reading text, `quiet`, `small`, `jp`).

**Icon** draws a line glyph by `name` in `color`, `size` px square, a
`stroke` (1.2) wide at any size: 12 in a button, 16 in the sidebar, menus
and the palette, 40 or so and `Theme.textFaint` for an empty page. Headings
and card titles stay words. The chrome's own sit on a 14-unit grid; the
rest are [Lucide](https://lucide.dev)'s (ISC, `CREDITS.md`) on its 24, drawn
thinner. A new one is Lucide's SVG with circles, boxes and lines written as
paths, added to `lines` in `Icon.qml` and to the list here.

| Group | Names |
| --- | --- |
| The chrome's | `arrow-left`, `arrow-right`, `arrow-up-right`, `close` (also `x`), `tick` (also `check`), `chevron-down`, `search`, `plus`, `minus`, `play`, `sound` |
| Places and pages | `home`, `sun` (today), `sunrise`, `moon`, `bed`, `calendar`, `days`, `week`, `grid`, `clock`, `history`, `timeline`, `chart`, `trend`, `activity`, `settings` |
| Writing and learning | `book`, `book-open` (a dictionary), `diary`, `pen` (write), `edit`, `cards` (a review), `layers` (decks), `languages` (kana), `mic`, `flame` (a streak), `target`, `checklist`, `smile`, `tag` |
| Watching and listening | `library`, `compass` (discover), `telescope`, `sparkles` (a season), `star` (picks), `heart` (favourites), `bookmark`, `eye`, `orbit` (a galaxy), `film`, `tv`, `music`, `disc` (an album), `user` (an artist), `list`, `playlist`, `queue`, `radio`, `antenna` (stations) |
| Actions | `pause`, `skip`, `skip-back`, `shuffle`, `repeat`, `volume`, `mute`, `download` (export), `upload` (import), `refresh`, `trash`, `more`, `link`, `external`, `info`, `alert` |

**The ready rule** (when a picture is taken): the window shows the Shell
or Connect; nothing is still taking its place (`Theme.settling`: Settle,
Card, Chart, a Screen's and a PageHead's arrival, the Shell's page change
and hero, a Picture asked of its store, loading or fading in, the Tour, a
Moment coming or going); every command has replied (`Sol.waiting`); and
then 150 ms without a new frame. A page where something never stops moving
(a primary button's breath, a turning world, a busy sweep) keeps painting,
so there it is a second with nothing settling (longer than any arrival
not counted). A component of a world's own with a long arrival or a timer
before its staging counts it with `Settling { when: anim.running }`.

**Primitives**: `Ticks` (the focus mark, rounded with what it marks:
`radius`), `Rounded` (an image's picture with rounded corners, cut in a
shader: what Picture and the flying hero draw with), `Settle` (arrive when
seen, a stagger apart; `pop` for a tile in a grid, `pushed` for a row
under a press), `Lean` (a thing leans to the pointer and, with `presses`,
gives under a press: put it last inside the thing and list its
`transforms` in the thing's `transform`), `PageTurn` (the world's way of
turning a page, which the Shell plays over its pane), `Settling` (a picture for review waits while
`when` holds), `Underline` (a field's line and its focus light),
`Caret` (the text cursor).

**Assets** (`assets/`, in the module's resources): the fonts (`fonts/`: Outfit, Shippori
Mincho, Zen Kaku Gothic New, Chakra Petch and Corporate Logo Bold, each with its
`OFL-*.txt` licence; `src/fonts.rs` and `cpp/fonts.h` register them at
start-up, and `scripts/fonts.py assets/fonts` fetches the Google Fonts ones
at a fixed commit and cuts the Japanese families to JIS X 0208, kana,
punctuation and Latin, kept TrueType or OpenType so nothing is unpacked at
start-up; `scripts/fonts.py --cut` cuts one already downloaded, as
Corporate Logo is, `--space` narrowing its space and `--palt` giving it
proportional punctuation; a world's own title face lives in that world's
repository and is added with `sol_quick::add_font(include_bytes!(…))`
before `run`), every world's photo (`worlds/`), the sounds (`sounds/`,
generated WAVs; `chime.wav` too; `scripts/world-sounds.py` makes each world's own, `<world>.wav`; `scripts/night-sounds.py` makes Luna's rain, fire and space loops, which Luna keeps itself), `sol-tray.png` (the tray's icon),
`widget/DesktopWidget.qml` and `capture/Capture.qml` (quick capture's line),
loaded by URL from outside the compiled module (they import
`org.kde.layershell`, which may be missing). **Shaders**
(`shaders/`): the body's lighting, the glass, the rounded picture
(`picture.frag`, Rounded's), a star's light and arc (`light.frag`,
`arc.frag`, StarLight's and StarArc's) and the cut glass (`hud.frag`,
HudGlass's, with `hud.vert`, which finds where the glass is drawn on the
window), committed as `.qsb`; after changing one, from `shaders/`:

```sh
for f in body glass picture light arc hud; do /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o $f.frag.qsb $f.frag; done
/usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o hud.vert.qsb hud.vert
```

## Writing a screen

A page is a `Screen` (a `PageHead` in `header`, cards below), the first one
a `Sheet`. State the screens share goes in the world's own singleton
(`qml/<Name>.qml`, `pragma Singleton`), which every file that uses it
imports with `import Sol.<Name>`. Lists are `Repeater`s whose delegates are
`Settle`d. What the design kit's `DESIGN.md` says about words, spacing and
motion holds here unchanged; [DESIGN.md](../design/DESIGN.md) has the QML
notes.

The window is the world's still under its grade, and everything on it
takes its colours from the world's flavour (`Theme.hud`): its ground, its
glass and its two lights.

| Token | What it is |
| --- | --- |
| `Theme.deep` | The flavour's ground, a little see-through: what lies behind a page's chrome where there is no glass |
| `Theme.space` | The flavour's ground (`hud.ground`: Saturn's `#0b0e2a`), under everything before the still is drawn |
| `Theme.raised` / `raisedTop` | The flavour's glass tint (`hud.glass`): what `HudGlass` lays over the blurred still |
| `Theme.textWorld` | A panel's title, in the flavour's accent, over a hairline that splits head from body |
| `Theme.light` | The flavour's glass is light (Terra's noon): the words on glass (`text…`, `hudText`, `hudQuiet`, `hudFaint`), `ink`, `deep`, `danger` and `ok` are dark |
| `Theme.artBright` / `artText` / `artQuiet` / `artFaint` / `artAccent` / `artSecond` / `artLine` | Words and marks on the still itself, not on glass (a Sheet's title card, `HeroFigure`s in a PageHead's feature, a sparse page's big title, moon links, moments): always light; over a dark flavour the same as the glass's |
| `Theme.frost` | The tint live glass lays over the page (menus, the palette, dialogs): the ground, or a light flavour's frost |
| `Theme.hudPrimary` | The primary button's fill: the accent, or the flavour's `primary` (Terra's sunflower, where its ramune blue is too deep for words on it) |
| `Theme.textInverse` | What is drawn on something filled in the words' colour: a ticked box, selected text |

Corners come from one scale whose four steps are all 0: the corners are
square, and the names stay so a thing still says which corner it follows.
Panels cut one corner at 45° (`Theme.hudCut`); a `Chip` is a pill.

| Token | Value | Where |
| --- | --- | --- |
| `Theme.radiusS` | 0 | A `Check`'s box, a `Skeleton`'s lines, a `Chart`'s bars, the pairing code, an `Editable`'s or a link's focus ticks; worlds: badges inside a picture, Terra's week ticks, thumbnails under 48 px |
| `Theme.radiusM` | 0 | `Button`, `Chip`, `Back`, a `Picture` (posters, covers, stills), a menu's, list's or palette's row light, a `SidebarRow`, a `Chart`'s tip; worlds: tiles, kana cells, Saturn's watched tick, a lifted queue row |
| `Theme.radius` | 0 | `Card`, every `GlassPanel` (menus, the `Select` list, `Hint`, `Notice`, the palette), the pairing card's glass; worlds: a big cover or poster, Saturn's continue card, Titan's galaxy, Saturn's month |
| `Theme.radiusL` | 0 | Big surfaces on their own: `Ask`'s dialog, the `Shortcuts` sheet, the desktop widget |

Groups are raised as panels, with ticks kept for focus and for a card
under the pointer. The web kit (`../design`, Sol's web app) still has the
older palettes and rounded corners (`docs/yozora-plan.md`, Stage 6, brings
it over): its `tokens.css` copies the palettes, its `Body` is `body.frag` in
WebGL, and its world data is written from `Worlds.qml` by its
`scripts/worlds-from-qml.mjs`, so a change to a world, a token or the
shader here is made there too.

On a light flavour nothing with words stands bare on the still but the
title cards: a page's figures go in its PageHead's `feature` as
`HeroFigure`s (which use the `art…` tokens), and a control on the page sits
on a Card (Settings' list stands on glass by itself there).

Text has a hierarchy: a fact's label is quiet (`textQuiet`), its value is
bright (`text`), reading text is softer (`textValue`), and `textBright` is
for names. Every world has a `role` (`Worlds.qml`, and `sol-world.json` for
the app menu): what it is for in a word or three, shown under its name in
the sidebar, in its doors and moon links, in the window title, the tray
and the app menu ("Terra · Habits and diary").

What QML's JavaScript lacks or forbids (no `flat`, the names final on
`Item`, a wheel told from a touchpad) is listed in `CLAUDE.md`, "Pitfalls".

## The gallery

`examples/gallery` is the kit in its own window: every part of
`Sol.Design` on six pages, as Shell sections, with sample data and the
kit's own photographs. **Worlds**: the window's world's Sheet (each world
in turn, ← and →), every Body at 22, 48, 120 and 300 px, every
WorldGlyph, every Icon by name. **Controls**: every Button variant resting, busy and off,
Chip, Check (on, off, busy, failing), Toggle, Slider, Field (empty,
typed, invalid), TextArea (and `large`), Select, Editable, Back,
MoonLink, a page's `Key`, Ticks. **Panels**: Card in its ways, Grid at
three widths, DataRows, Display, Progress, Callout, Settle, every
Skeleton and Chart, Strip, Picture and Poster (loaded, missing, dim,
lifted), Empty (both ways), the Navigator's portrait, chip and bubbles
(Cheer plays its cheer), a masonry Grid with a feature card across two
columns and one across the row (Again grows one; the cards under it
glide). Panels is a section with children: **Tabs** (a PageHead's tabs,
`/tabs?tab=calendar`) and **Menus** (a card and rows that are things,
each with its right-click and ⋯, a nested "Rate…"; `_nested=1` opens it). **Overlays**: ContextMenu, CommandPalette, Ask, notices, Hint, the Tour (`_tour=1`), a Moment
(`_moment=1`; `SOL_CALM=1` for its still form), quick capture (`_capture=walk`,
answered by the gallery's own `ask`). **Sky**: `SkyPage` (its map a
`StarField`) on the gallery's own `sky` command (four constellations, some stars lit), a star chosen
(`?star=ghibli/spirited`), the star's moment (`_moment=star`); the comet
and the full moon on Luna's Sheet are `/?_world=luna&_comet=1&_sky=full-moon`;
the moon's sky on its own tab (`/moon/sky` leads there). **Settings**: the
window's cards on a masonry Grid, then the moon's part under its name
(`MoonSettings`, from the moon's `settings`; `/moon/settings` opens it
there). The moon (**Tonight**, its one page) is carried as Luna is in
Terra.

```sh
scripts/hidden.sh -- cargo run --example gallery   # by hand: a preview, no Sol, no network
scripts/gallery-shots.sh /tmp/shots               # after a kit change: every page once for each flavour, the journal (a build only when needed)
scripts/shots.sh terra /tmp/t today=/ end='/?_scroll=end'   # a world's pages, in one run (builds nothing)
SOL_HIDDEN_SIZE=1920x1080 scripts/shots.sh …       # the hidden display at another size (hidden.sh's --size)
scripts/yozora-art.sh                             # the Yozora look's stills and navigators, into ~/.local/share/sol-yozora (this computer only)
scripts/fonts.py assets/fonts                     # the fonts, from google/fonts at a fixed commit, the Japanese two cut to size
scripts/fonts.py --cut <font> <out> [--space 0.25] [--palt]   # a face already downloaded, cut the same way
```

`gallery-shots.sh` takes its pictures in seven runs (one for each flavour,
`SOL_FLAVOUR=saturn|mercury|neptune|terra|luna`, then less motion and narrow),
each one launch taking a list (`SOL_SHOTS`); the gallery's own keys follow
each picture of a run. A flavour's pictures are named `<flavour>-worlds`,
`-controls`, `-panels`, `-overlays`, `-sky`, `-tabs`, `-settings`; each page
is taken from its top to its end a view at a time (`-2`, `-3` … `-end`, the
views that only repeat the one before dropped), so every component is in a
picture, and its staged parts beside; the states one picture can't hold are in Saturn's run
only, then `calm-overlays-moment` and `narrow-worlds|controls|tabs`.

Its QML (`examples/gallery/qml/`) and the kit's are read from this
checkout, so `gallery-shots.sh` builds only when something besides `.qml`
changed or a `.qml` file was added or removed (`--build` builds anyway).
It is an example, so the worlds get nothing from it. Besides the usual `_` keys, its shot path takes `_world=saturn` (the
window as that world), `_focus=field` (`button`, `field`, `textarea`,
`slider`, or `select` with its list open) and `_menu=1` (the menu open on
Overlays).

## Checking a screen

How to run, shoot and read a preview (always inside `scripts/hidden.sh`)
is in `../../docs/agents.md`; a change to the kit itself is looked at in
the gallery (above), not in every world.

## The desktop around the window

- **One Sol tray** (`core/src/tray.rs`): the first Sol app to start shows a
  single Sol icon; the others join it, each as a submenu (Open, the entries
  a world lists in `World::tray`, Quit), and the next takes over when it
  quits. Closing a window hides it while the tray is there.
- **The navigator's cheer**: `Sol.cheer()` after the world's main good
  act (an episode watched, a habit ticked, a card remembered): every
  navigator in the window glows warm and sparks once (`Sol.react(kind)`,
  the `reacted` signal).
- **Counts**: `Sol.badge(10, "due")` puts a count beside the app in the
  tray, in its tooltip, and on its icon in docks that read the Launcher
  Entry API.
- **Desktop widgets**: a world sets `widget` (a Component) and
  `widgetName` on its `AppWindow`; Settings → On this device shows it on
  the desktop (a layer-shell panel in a corner, under the windows) while
  the app runs. Wayland with layer-shell-qt only; elsewhere nothing shows.
- **Start with the computer**: the installed copy can start at login in
  the tray, without a window (`autostart` / `set_autostart`; the entry
  runs it with `--login`, so a moon started at login stays when its planet
  isn't running).
- **Notifications**: `notify` shows one with an optional button; what was
  pressed comes back as a `notified` event (Terra's reminders tick the
  habit from one).
- **Global keys**: `World::shortcuts` binds them through the desktop's
  portal and sends a `shortcut` event on each press; the desktop may ask
  to confirm them the first time. Neptune's MPRIS (media keys, the
  desktop's player widget) lives in its audio crate. Umbriel has no such
  portal: its keys run `--do` instead (below).
- **The bar, the launcher, the terminal** (`core/src/status.rs`): a world's
  `status`, `do`, `find` and `ask` commands, written to a status file and
  answered through its door (`--status`, `--do`, `--find`, another world's
  `questions::ask`), said once in a `desktop::Desktop`; all of it in `docs/world-apps.md`, "The desktop around
  the app". The Sol desktop (`deploy/desktop`) reads them.

## Quick capture and Undo

Quick capture (one line over the desktop, done by whichever running world
understands it; `core/src/capture.rs`, `assets/capture/Capture.qml`) and
`Sol.undoable` (a write taken back from its notice; `Commands::undoable`,
`core/src/undo.rs`, the shared `undoable` and `restore`) are described, with every world's capture verbs,
in `docs/world-apps.md`.

## Work is never lost, updates roll back

What `run` and `orbit::link::Link` do so a person never loses what they
wrote, and an update never leaves them without the app:

- **Writes kept aside** (`Sol.kept`, `KeptAside`): a document changed here
  and on another device (each write says which version it was made on,
  `if_version`) keeps Sol's copy in place and this one beside it, until
  the person chooses; a write Sol turns down (too large) is kept with
  Sol's reason; writes still waiting when the device is unpaired (a `401`,
  or Unpair) are kept and sent once it pairs again as the same person. The
  window shows a notice with a button for each new one ("Changed on
  another device too", "See both"); the Sol card lists them.
- **A local copy that won't open** (written by a newer version, or
  damaged): the window shows why instead of the app, with Start fresh
  (the copy is set aside as `<world>.db.set-aside-<time>`, everything comes
  from Sol again) or Quit. Before a migration changes the copy it is
  backed up into `backups/` in the data folder.
- **Updates**: the new binary is started with `--version` first (it must
  say the offered version, and the Qt this computer runs, `Terra 1.0.0
  (Qt 6.12.0)`); the old one stays as `<bin>.old`. A new version that
  starts and never comes up (its window doesn't load, or it crashes
  before ten seconds) is rolled back on the next start, the local copy
  too (from its backup), and Settings says so; it isn't installed by
  itself again. `World::update_key` may hold several keys, one per line.
- **Stopping**: SIGTERM and SIGINT quit as the tray's Quit does (the
  window's size is kept, the door closes); a moon its planet started
  leaves about five seconds after the planet does (it waits on the
  planet's lock, so a crash counts too).
- **The log**: `~/.local/state/digital.sachi.sol.<world>/<world>.log`
  (`<world>.log` in the preview's folder), started again at 2 MB with the
  one before kept as `.log.1`; moons and apps started at login write there
  too, panics included. A crashed sync loop starts again by itself.
- **The keyring at login**: while it is still locked the app says
  "waiting for the keyring to unlock" and syncs once it opens, instead of
  asking to pair again.

## The sky, charts, instant start

- **The real sky**: Luna shows tonight's phase and Terra's light follows
  the local hour wherever a body is drawn (`Worlds.skyOf`, `Worlds.moonAt`).
  A full moon or the Perseids on Luna's Sheet and Saturn's opposition on
  Saturn's say so at the band's bottom right (`sky_tonight`).
- **Charts**: `Chart` draws bars or lines for one or more series over the
  same labels, grows in when seen, and says the exact values under the
  pointer.
- **Instant start**: `Sol.callSeen(command, args, use)` hands a page what
  it showed last time on this device at once, then the fresh reply; kept
  in the app's data folder (`seen/`), written only when it changed.
  `Sol.fill(item, name, command)` does it for one property.

## Menus

Every card or row that is a thing (a title, a deck, a station, a habit)
has the same menu on a right-click and under a ⋯: one function of the
thing returns its entries, and it is given to all three.

```qml
function stationMenu(s) { return [{ label: "Play", icon: "play", run: … }, { label: "Rate…", items: [1, 2, 3].map(n => ({ label: String(n), run: … })) }, { separator: true }, { label: "Remove", danger: true, run: … }] }
Card { title: s.name; menu: () => page.stationMenu(s) }                        // right-click, and a ⋯ in its head
Item { MenuArea { anchors.fill: parent; menu: () => page.stationMenu(s) }   // a row's right-click (clicks go on through)
       MoreButton { anchors.right: parent.right; menu: () => page.stationMenu(s) } }
win.menu.openAt(item, mouse, entries)   // from a MouseArea of your own: at the mouse, or under `item` with no mouse
```

The same entries may go in a page's `actions`, so the palette has them too.

## The palette and the hero

Ctrl+K opens the **command palette** (`CommandPalette`): the sections
(with their children and tabs as you type), the window's `commands` and
the page's `actions` (all of them when nothing is typed), and what its
`find` turns up as you type (Saturn searches titles, Neptune the library,
Mercury the dictionary). A row with `items` opens its own list (Enter or
Right; Left or Escape goes back out), and typing finds the entries inside
it too ("rate 8").
`Shell.go(path, params, { item, url })` flies a picture from where it was
clicked to the new page's `hero` (a poster to the title page, a cover to
the album). `Tone` reads a picture's colour for tinting; `Spark` is a burst
of particles for a moment that earns one.

## Feel

The first screen's `Sheet` goes in the page's `header`: it stays while the
page scrolls under it and shrinks to a bar, the world sinking into the
corner and the name taking its place. Cards and `Settle`d rows arrive when
they scroll into view, not before. Pages have real inertia: a drag past the
end gives and springs back, the wheel bounces at the ends. A page opened
from another slides in from the right and back out; a section settles.
Each turn is the world's own (`PageTurn`): a slanted wipe in its light with
the PageHead's words sliding in behind it, Saturn's a film's cut with black
bars, Neptune's red with a cyan ghost under its glitch, Mercury's an ink
wash clearing from the title, Terra's a soft sweep of sunlight; going back
runs the other way, and less motion only fades. A tab (or a Settings
part) is no new page: it changes with a plain fade, no turn.
The sidebar's field filters the page in place when the page says
`filters: true` (it reads `filter`), and searches the app otherwise; `/`
focuses it (on the rail it waits behind a button and floats over the pane).
The arrows, Page Up / Down, Home and End scroll the page. Keyboard focus
shows as `Ticks` on buttons, chips, checks, toggles, moon links, a card's
Open, `Editable`, the way back and the accent swatches, two corner ticks
bent round the control's own corner a few pixels out (arcs round a switch
or a swatch); a field, a text area and a list choice light their
underline instead, and a slider its ring. A `PageHead` too narrow for its
actions puts them on lines of their own under the title. `Editable` turns
words into a field on click, or Enter (a `PageHead` with `editable: true`
renames); `Check` shows the click at once and takes it back with a shake
on `fail()`; a `Card` with a `menu` opens it on right-click and from its ⋯. `Skeleton`
draws a page's shape while its data is on the way. `Sounds` (on and low
unless turned off in `DeviceCard`) gives a tick, a done and an off. Fractional scaling works as
Qt does it: `QT_SCALE_FACTOR=1.5` to check.

## Motion

Every screen settles into the pane and settles again when the Shell comes
back to it; the page it replaces fades under it. Lists arrive with the
stagger, bars grow from their baseline, figures count up, cards settle
with the spring and lean a pixel or two to the pointer, things that act
give under a press, the first screen's band drifts with the scroll, the
pairing scene breathes a few times and rests, and menus, notices,
hints and the dialog sit on real glass, the page blurred behind them and
bent a little at the panel's edge. The worlds are alive: clouds drift over
Terra, Neptune and Titan, Sol's corona flickers, their rims of air breathe
(`live` in `Worlds`, `time` in the body shader). Switches and the sidebar's
light land with a spring. Every length and curve is `Theme`'s, and nothing
else writes a number of milliseconds or an `Easing` (the QML lint warns of
one; `// not a token: <why>` beside a deliberate one, like Luna's night
sound fading over a minute): `snap` (a press), `flicker` (a glitch's or a
shake's step), `lock`, `fade`, `settle`, `turn` (a page arriving), `count`
(a figure counting up), `rise`, `wash` (a colour over the whole window) and
`stagger`, all nothing for `SOL_SHOT_CALM` pictures; `sweep` (a busy mark),
`drift`, `crossing` (the comet), `scene` (a moment), `notchGlide` and
`touchGlide` (the page under a wheel or a touchpad), which never are; and
the curves `ease`, `easeOut`, `spring` (a tenth past its place and back)
and `easeInOut`, given whole: `easing: Theme.easeOut`. Timers that decide
something (a hint's wait, the caret's blink, a search's pause) keep their
own. Nothing moves without saying what
changed, and nothing loops while the window is hidden or behind another
(`Theme.alive`). `SOL_FPS=1` writes the frames painted a second to the
journal: 170 on a 170 Hz screen.

Look at the picture before calling a screen done, and read the journal: a
binding that fails leaves a card empty without a word on the terminal.
