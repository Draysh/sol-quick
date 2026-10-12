# sol-quick (kit/quick)

The design language in Qt Quick (the QML module `Sol.Design`, `qml/`) and
the Rust side every world app shares, in two crates of one workspace and
one tag: `sol-quick` (`src/`: `sol_quick::run`, the window, `SolBackend`,
live QML: what needs Qt) and `sol-quick-core` (`core/src/`: everything
else: commands, the desktop, questions, doors, undo, moments, export, the
test helpers). `sol-quick` re-exports core under the same paths. A Rust
file named below without a folder is in `core/src/`, except `bridge.rs`,
`live.rs` and `app/start.rs` (`src/`).
Every world app and `kit/template` build on it; Sol's own web app does not
(that is `kit/design`). `README.md` lists every component and module;
`docs/world-apps.md` is the guide for working in a world.

## Who sees a change here

- The worlds pin a released tag: the app `sol-quick = { git, tag =
  "v1.x.0" }`, its logic crate (`crates/<world>-core`) `sol-quick = {
  package = "sol-quick-core", git, tag }` (cargo finds `core/` in the same
  repository), so an edit reaches nothing until they point at it.
  `hub/scripts/worlds.sh use-local` points every consumer at this checkout
  (`path = "../../kit/quick"`, `"../../../../kit/quick/core"`); then
  `cargo build` in a world compiles this crate's QML too, and `cargo test
  -p <world>-core` compiles only core.
- **Core never needs Qt**: no cxx-qt, nothing from `src/`, no feature that
  changes what it builds for an app and for its tests (one would make
  cargo build `sol-quick`, and run its Qt build script, once per variant).
  So the test helpers are always built and orbit's `testing` is always on;
  a door's name is chosen at run time (below). What `src/` needs from core
  that a world mustn't is `#[doc(hidden)] pub` (`Runtime`'s fields,
  `single`, `shared`, `seen`, `tray`, `autostart`, `status::start`).
- Installed apps on this computer may run older kit versions side by side:
  anything that crosses processes (sockets, settings files, the tray's
  messages) must stay compatible.
- A new helper goes where a world agent would look for it (`Sol`, `Theme`,
  `Format`, or a component), documented with a `/** … */` line like its
  neighbours, and listed in `README.md`.

## Adding or changing a component

- Drop `qml/Foo.qml`; `build.rs` registers every `.qml` under `qml/` (no
  `qmldir`). A singleton has `pragma Singleton` among its leading lines
  (only blank lines, other pragmas or `//` comments before it) and must
  `import Sol.Design` to see `SolBackend`.
- Inside the kit, Qt's own `Screen` wins over ours: `import Sol.Design as
  Design` and write `Design.Screen` (casts: `x as Design.Screen`).
- A shader: edit `shaders/<name>.frag`, rebuild the `.qsb` with the
  command in `README.md` (they are committed; the build only packs them).
  Uniform names must match the properties of `Body.qml` / `Glass.qml` /
  `Rounded.qml` / `StarLight.qml` / `StarArc.qml` / `HudGlass.qml` (and
  `Navigator.qml`, whose portrait frame is drawn by `hud.frag` too).
- Corners: `Theme.radiusS` / `radiusM` / `radius` / `radiusL` (4, 6, 10,
  14; README has where each goes), never a literal. Something drawn over
  a rounded thing (a hover fill, a hairline frame, a badge in its corner,
  a busy sweep, a progress line along its foot) takes the same radius or
  stays clear of the corners; `Ticks` take the control's `radius`. A
  picture rounds through `Picture.radius` (Rounded, a shader: no layer,
  no MultiEffect mask); `clip` is square, so a rounded box that clips
  must keep its children off the corners.
- Assets in `assets/` are packed into the module (not `.txt`/`.md`); QML
  reaches them as `../assets/…` from `qml/`.
- Every file starts with a `/* … */` block saying what it is, with a usage
  line; properties a world sets get a `/** … */` line.
- A new component, variant or state goes on the gallery page it belongs
  to (`examples/gallery/qml/`: Worlds, Controls, Panels, Overlays), with
  sample data only. The gallery is an example, not part of the library:
  it adds nothing to `Sol.Design` or to what a world links, and its QML is
  read from this checkout when it starts (an edit there needs no build).

## Hidden contracts (an edit can break these silently)

- **Screen's header slot** sets `width` on each header child, `screen`
  when the child has one, and pins a child that has `collapse` and
  `fullHeight` (a Sheet keeps `collapse`, `fullHeight`, `compact`; a
  PageHead keeps `screen` and `reveal(dir)`). Pages must not declare their
  own `reveal`: the Shell calls it.
- **The Shell makes pages** with `params`, `shell`, `visible`, `width`,
  `height`, then sets `back`, `x`, `opacity` (and `params` again for a
  section's one page on another tab: `retab`, a step back), reads `title`, and casts to
  `Design.Screen` for `filter`, `filters`, `scrollBy`, `pageStep`, `hero`,
  `restingPoint`, `wheel`, `notch`. The Sidebar reads `filter`/`filters` and the Shell's `rows`,
  `currentRow` and `worldOf`. `go` follows `aliases` (the window's and,
  under `/<moon>`, each moon's, from CarriedMoons, which adds
  `/<moon>/sky` → `/sky?tab=<moon>` and `/<moon>/settings` →
  `/settings?part=<moon>`) only where no page has the path; a tab's own
  page is keyed `path?tab=<id>` in `pages` and `sectionPages`, and
  `retab` swaps it into the step (a page no section keeps is destroyed
  once it has left: `dropping`). SkyPage reads the Shell's `moons` and
  `pages` for its tabs; MoonSettings reads `Window.window.moonSettings`
  and its Screen's `params.part`. A PageHead with `tabs` calls
  `screen.shell.retab(params)`; AppWindow finds it among the page's
  `header` (`tabs`, `current`, `choose`) for the palette's tab rows.
- **The hero flight** reads `rounded` and `radius` from the item it
  flies from and the page's `hero` (a Picture has both), and turns the
  one corner into the other on the way.
- **Containers that place children**: Grid writes `card.index`, reads
  `card.span` and calls `card.glide(dx, dy)` when it has one, and skips
  Repeaters (`Theme.isRepeater`); PageHead reads `Button.natural`;
  `Button.room` walks up to a parent with `childRoom` (Sheet sets it);
  Grid lets go of its cards' signals on destruction (a grid made by a
  Loader, a moon's settings part, otherwise warns as the app quits);
  `Theme.whenSeen` finds the nearest Flickable (`contentY`,
  `contentHeight`, `contentItem`); `Theme.screenOf` the nearest Screen.
- **`Window.window as AppWindow`**: Glass reads `backdrop`; HudGlass `shell.ground` and
  `shell.groundBlur` (a page's glass in the Yozora look reads the one blurred ground, not the
  frame it sits in; GlassPanel's, over the pages, blurs `backdrop` live); Card,
  MenuArea and MoreButton `menu.openAt`; Key `ask.current`, `commandPalette.open`, `menu.open`;
  DeviceCard `widget`, `widgetsHere`, `widgetPrefs.*`, `widgetName`;
  `assets/widget/DesktopWidget.qml` `host.widget`, `host.widgetPrefs.corner`;
  `assets/capture/Capture.qml` `host.capturing` (it sets it false to
  close) and `host.stagedCapture`; the Shell's `?` sheet `tour`,
  `tourSheet.show()` and `allCommands` (the window's `commands` and the
  page's `Screen.actions`, which the palette lists too); the notice stack
  `shell.pageArea`; SolCard `keptAside.open`. Worlds read `menu`, `ask`,
  `keptAside`, `moment`, `shell`, `started` and set `commands`, `find`,
  `footer`, `busy`, `warn`, `tour`, `moments` (`_moment=<name>[:<arg>]`
  plays one; `stageMoment` reads the arg after the first `:`).
- **Notice's required properties** match the roles of `Notices.list`
  (`key`, `world`, `title`, `body`, `tone`, `action`); a delegate must not
  redeclare `model`. A notice's `run` lives in `Notices.runs` by key, not
  in the model (a ListModel can't hold a function).
- **Moments**: a world that plays one lists `moments` among its collections
  (`moments::MOMENTS`; the documents are `{ occasion, at, device }`, the id
  `occasion_id(occasion)`; `testing::assert_manifest` checks the listing).
- **The Sky**: lit stars are documents in the world's `sky` collection
  (`sky::SKY`), `{ v, constellation, constellation_title, star, title,
  story, at }`, the id `star_id(constellation, star)`; a constellation's
  and a star's ids are for good (they name lit stars). Every world with a
  Sheet lists `sky` (comets are caught there; `assert_manifest` checks).
  `SkyPage` calls the world's own `sky` command (`sky::show`'s `View`:
  `constellations`, `stars` with `key` `<constellation>/<star>`, `lines`,
  `lit`, `total`); the kit's event `sky.lit` (a `Lit`) plays `StarScene`
  from AppWindow; `comet`, `catch_comet` and `sky_tonight` are shared
  commands; the comet's days come from `fingerprint("comet.<world>.<day>")`,
  so changing it moves every world's comets. AppWindow's `stagedComet`
  and `stagedSky` (`_comet`, `_sky`) are read by Comet and the Sheet.
- **Carried moons** (`docs/world-apps.md`, "Moons"): `run_with` claims each
  moon's door before opening its link (two processes must never open one
  local copy), asks a standalone moon still running to quit (SIGTERM, five
  seconds), and runs the moon's commands with the shared ones on its link.
  The bridge adds `moons` (JSON by id: `name`, `status`, `unsent`, `kept`,
  `problem`, `settingsVersion`), `callIn`, `callSeenIn`, `manifestOf` and
  the signals `eventIn`, `changedIn`; every older name still means the
  app's own world. `Sol.of(id)` caches one `SolWorld` per world;
  `Theme.screenOf(item).world` is what `Sol.near` reads. A moon's pages
  live under `/<moon>` (`Shell.worldOf`), its QML module is found through
  `Moon.module` for live QML. A problem `"elsewhere"` (its own app still
  holds its copy) shows on its pages. The moon's crate's `qml` is a link
  to the repository's `qml/`, so the module's files keep `qml/<File>.qml`.
- **The Yozora look** (`../../docs/yozora.md`): every token that changes with it is
  `yozora ? … : <as before>`, so with the look off nothing moves by a pixel (check the
  gallery night and day against a "before"). The Shell picks the ground (`groundSource`:
  the page's `Screen.ground`, else `Theme.groundsOf(world)` by the section's `top`, or a
  moon's own stills, `Theme.ownGroundsOf(moon)`, counted from its first section) and
  the navigator's line (`navigatorLine`: `Screen.say`, `Screen.emptySay` (written by a
  showing `Empty`), a greeting, the row's `hint`); PageHead reads the Shell's `history`
  and `rows` for its number and a section's `jp`; SidebarRow takes `jp` and `moon`. The
  bridge's `lookArt` lists `~/.local/share/sol-yozora/` once at start, only with
  `SOL_LOOK` set; nothing in the kit or a world may ship those pictures.
- **Singletons written from outside**: `Theme.world` and `Theme.worldId` (Shell; `world`
  also DeviceCard),
  `Theme.picks` (Shell's Tone), `Theme.alive` (AppWindow), `Worlds.surfaces`
  (a world, through `Worlds.setSurface`: Terra's `green` and `cloudy`, the
  body shader's last two uniforms).
- **Settings files**: `~/.config/sol/device.conf` `[appearance] mode` and
  `motion` (`full` / `less`: `Theme.calm`) (every Sol app); the app's own
  file (name from `set_application_name` and `set_organization_domain("sachi.digital")` in `run`) with categories
  `sol.device` (sounds) and `sol.<world>` (`accent`, `widget`, `corner`,
  `toured` (the first-run tour seen); Luna's `nightSounds`, `nightVolume`;
  Neptune's `notToday`; Triton's `dj`). A preview shares the installed app's
  file: the tour writes `toured` only outside a preview.
- **The world's voice**: `Sounds.voice()` plays `assets/sounds/<Sol.world>.wav`
  for the worlds in `Sounds.voices`; a new world adds its line there and in
  `scripts/world-sounds.py`.
- **Rust ↔ QML**: every `SolBackend` property, method and signal name
  (`bridge.rs`); the commands the kit's QML calls (the shared ones in
  `README.md`: `moment` from Moment, `undoable` and `restore` from
  `Sol.undoable` (`commands.rs` answers `undoable { command, args }` with
  `{ result, undo }`, the token `restore { undo }` and `undo::take` read;
  `undo.rs`), `capture` from Capture.qml, plus `notify` and the
  rest); the events `tray`, `shortcut`, `notified`; the JSON of `orbit::link::Status`, `orbit::link::Kept`, `KeptWrite`
  (the `kept` command) and `orbit::updates::Status` (Connect, SolCard,
  KeptAside, AppUpdates and `Sol` read their fields, `rolled_back` too);
  `SolBackend.problem`'s `{ problem, path, detail }`. `SolBackend.changed`
  (the collections, a JSON list; empty for "any") reaches the screens as
  `Sol.changedIn`, which `Watch` filters; `callSeen` answers with
  `recalled(id, body)` first and `repeated(id)` before `replied` when the
  reply is what was kept (`seen.rs`, `through`).
- **Across processes** (what they mean: `docs/world-apps.md`, "The desktop
  around the app" and "Quick capture"): the tray socket (abstract
  `sol-tray:$XDG_RUNTIME_DIR`, JSON lines of lowercase `Up`/`Down`,
  `tray.rs`); the single-instance door, abstract `sol-<world>:$XDG_RUNTIME_DIR`
  / `sol-preview-<world>:…` (`sol-test-<pid>-<world>` in any process until
  `run` calls `single::use_the_computers_doors()`, so every test's doors are
  its own), plus
  the socket file `sol-<world>.sock` that versions before 1.0 use (knocked
  on before running, listened at; drop it once no 0.x app is left), with
  lines `show`, `open <path>`, `wait` and `ask do|find|ask|capture <json>`
  (answered `ok <json>` / `no <why>`; older copies answer only `ok`; `ask
  capture null` opens quick capture, answered `ok "open"`, which
  `deploy/desktop/bin/sol-capture` reads); the status file
  `$XDG_RUNTIME_DIR/sol/<world>.json` (`preview-<world>.json`), the world's
  `status` plus `world`, `name`, `pid`, `at`, read by the desktop's plugin,
  fastfetch and `sol-do`; the world commands `status`, `do` (`Do { id, arg
  }`), `find` (`Query` → `[Found]`) and `ask` (`Question { id, arg }` →
  JSON; `capture` is `Line { line, go }` → `Offer { does, sure }` / null,
  or with `go` one sentence), all four registered by `desktop::Desktop`
  (`register` adds only those with something to answer; `status` and `ask`
  reply as JSON text through `Commands::add_text`); the sure scale in
  `desktop/matching.rs` (`EXACT` 1.0, `VERB` 0.9, `PREFIX` 0.8, `ALL_WORDS`
  0.7, `SOME_WORD` 0.5, `GUESS` 0.3), which every world's offers are ranked
  on against each other; the questions worlds ask each other, typed in
  `questions.rs` (Mercury's `Furigana`, `Say`, `Level`, `AddWord`;
  Neptune's `Now`, `Duck`, `Pause`), whose wire (ids, JSON fields, `duck`'s
  and `add-word`'s JSON inside the `do` argument, `level` and `now` asked
  with a null) stays as installed apps speak it: the answerers'
  `fixtures/questions/*.json` and the askers' copies check it (who asks
  what: the table in `docs/world-apps.md`); the desktop file `sol-<world>`; the flags
  `--status`, `--do <action> [arg]`, `--find <words>`, `--background` (a
  moon its planet started), `--login` (the autostart entry), `--open
  <path>`, `--install`, `--uninstall`, `--version` (its line ends `(Qt
  X.Y.Z)`: `orbit::updates` reads it when it tries an update);
  SIGTERM/SIGINT quit like the tray's Quit.
- **Environment**: `SOL_PREVIEW`, `SOL_SHOT`, `SOL_SHOT_AFTER`,
  `SOL_SHOT_PATH` (and its `_` keys), `SOL_SHOTS`, `SOL_SHOT_READY`,
  `SOL_SHOT_CALM`, `SOL_FPS`, `SOL_DRIVE`, `SOL_LIGHT`,
  `SOL_CALM`, `SOL_LOOK`, `SOL_FAKE_NAVIDROME`, `SOL_QML_LIVE`.
- **Live QML** (`src/live.rs`, `cpp/live.h`; what it is for:
  `docs/world-apps.md`, "Live QML"): with `SOL_QML_LIVE=1` a preview maps
  `qrc:/qt/qml/Sol/Design/qml/<File>.qml` to this checkout's `qml/` and
  `qrc:/qt/qml/Sol/<World>/qml/` (from `World::main`) to `World::source`'s
  `qml/`. A file's folder on disk must stay laid out as in the module
  (`qml/`, `../assets`, `../shaders`).
- **Test helpers** (`testing.rs`, always built, with orbit's `testing`):
  the worlds' tests call `offline_link`,
  `assert_manifest`/`Expect`, `capture_q`, `assert_asked`, `assert_told`,
  `assert_copy`, `undoably`, `take_back` and `FakeDoor` by name; keep them
  and their meaning (`docs/world-apps.md`, "Tests").
- **The stand-in Navidrome** (`navidrome/`, feature `fake-navidrome` of
  either crate):
  Neptune's and Triton's previews and tests name its ids (`al-1`, `ar-2`,
  `pl-1`, `tr-1-1`) and counts (9 artists, 24 albums, 168 tracks); change
  the library and their tests change with it. It answers only what those
  two worlds' clients ask, in Navidrome's JSON shapes.

## Pitfalls

- QML's JavaScript: no `flat`/`flatMap`; `Promise.finally` exists only
  because `Sol.qml` adds it.
- `data`, `enabled`, `top`, `right`, `y` are final on Item: no custom
  properties by those names. `target: parent` in an animation is undefined
  (use an id). Repeater delegates must be Items (Instantiator for a
  Shortcut or ShapePath). No anchors inside a Flow. Qt 6 has no `Glow`.
  `required property int index; index: index` binds to itself (always 0).
  A property named `palette` clashes with Qt's (hence `commandPalette`).
- Glass reads the window's `backdrop`, so it must sit outside it: popups
  (menus, lists, hints) reparent to `Window.window.contentItem`. Glass
  re-places itself when any ancestor moves; keep that watch.
- Never reparent an item out of a Flickable's column (it stops rendering).
- No conditional anchors (`anchors.horizontalCenter: rail ? parent.horizontalCenter
  : undefined`): a released anchor leaves the item where the anchor put it,
  so a sidebar that starts as a rail for a moment kept its rows 5–19 px off.
  Bind the position instead (`x: rail ? (parent.width - width) / 2 : 12`).
- MultiEffect's mask cuts hard by default: a gradient mask only fades with
  `maskThresholdMin: 0.5; maskSpreadAtMin: 1; maskThresholdMax: 1;
  maskSpreadAtMax: 1` (Saturn's title hero). `autoPaddingEnabled` on a
  blurred small image smears its edge pixels into hard boxes; feather a
  glow with a mask instead (Saturn's ContinueCard).
- Idle frames: anything that loops runs only while `Theme.alive`; the
  Caret blinks in steps; a FrameAnimation would keep ticking; Body animates
  only moving worlds; Progress scales its fill instead of resizing it.
- Focus: a hidden field keeps the keys unless focus is moved; Ask and
  ContextMenu give focus back to where it was.
- Wheel: on Wayland Qt fills `pixelDelta` for a mouse wheel too; only
  `phase === Qt.NoScrollPhase` tells it from a touchpad (`Theme.wheel`).
- The hero is measured after `frameSwapped`; Tone gets no `imageLoaded`
  for an image already decoded; Settle/Card `whenSeen` must forget on
  destruction and treat a Flickable of height ≤ 0 as in view.
- Commands reply as JSON text (an `f32` through `serde_json::Value`
  widens); a panicking command still replies. A command's closure returns
  `anyhow::Result` and `Commands` says the error (`say`); `undoable` is a
  name `Commands::call` answers itself, so no world may name a command so. `SolBackend` subscribes to
  the link before reading its state.
- QML errors go to the journal, not stderr. `QT_QPA_PLATFORM=offscreen`
  draws neither the body shader nor glyph images: look at real windows,
  on the hidden display (`../../docs/agents.md`). A drive's TestEvent click needs a mouse move onto the item first.
  `SOL_SHOT` beside `SOL_DRIVE`: both run on their own clocks, and
  whichever quits first ended the run (a drive's `Qt.quit()` before
  `SOL_SHOT_AFTER` left no picture; the shot's quit closed the window
  under a drive still running, whose own grabs then failed with
  "grabToImage: item's window is not visible"). Now the shot doesn't quit
  while a drive runs; a drive takes its own pictures
  (`win.contentItem.grabToImage`) and ends with `Qt.quit()`, or the window
  stays open; a script that fails to load says so in the journal
  (`SOL_DRIVE: the script didn't load`). The shot's clock starts when the
  frame shows the Shell or Connect, not when the window opens.
- A world's own `qrc_resources` in its `build.rs` hid the kit's assets (every
  photo and shader failed to open): a world ships a file with `include_bytes!`
  and writes it to its cache folder (Luna's night sounds) instead.

## Checks

- `cargo fmt --all`, `cargo clippy --all-targets --all-features -- -D
  warnings`, `cargo test --all-features` (both crates: the workspace's
  default members; `--all-features` adds the stand-in Navidrome). While
  iterating on core, `cargo test -p sol-quick-core` builds no Qt.
- **Pictures wait for ready** (`WindowShots`, the window's `shots`): `Theme.settling`
  (every `Settling`: Settle, Card, Chart, Screen, PageHead, Shell, Picture,
  Tour, Moment, the frame) and `Sol.waiting` (commands not yet answered)
  at 0, then 150 ms without a frame, or a second when frames never stop. A
  new arrival longer than a second, or a timer before something shows,
  adds a `Settling`, or pictures catch it half-way. `SolBackend.shot` and
  `shotPath` are the current picture's (a batch writes them), so a
  binding on them follows each picture; something read once at start sees
  only the first.
- After any change here, the gallery: `scripts/gallery-shots.sh <folder>`
  (`examples/gallery`, every component on four pages, night and day, two
  narrow, and the focus, menu, palette, dialog and notice states, then
  what the journal said about the QML). It builds only when more than
  `.qml` files changed (`--build` builds anyway). Read the pictures,
  before and after (a control's focus shows only while the window stays
  in front). The gallery runs the Rust side too (it calls
  `sol_quick::run`).
- Build a world (with `use-local` on) only when its own screens use what
  changed, and look at those screens; never every world's pages.

## Releasing

1. Bump `version` in `Cargo.toml` (`[workspace.package]`, both crates';
   1.x.0 for anything new). While
   `use-local` is on, `orbit` is `{ path = "../orbit" }` in `Cargo.toml`
   and `{ path = "../../orbit" }` in `core/Cargo.toml`; a release points
   both at a released orbit tag first (`worlds.sh use-tags … kit/quick`), so the
   crate builds on its own from GitHub.
2. The person commits, tags `v<version>` and pushes (Draysh/sol-quick is
   public, so cargo can fetch it without credentials).
3. `hub/scripts/worlds.sh use-tags <orbit> <design> <quick>` points every
   consumer at the new tag; then each world is built, checked and
   released on its own (`hub/CLAUDE.md`).
