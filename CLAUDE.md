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
  `NavigatorFace.qml`, whose portrait frame is drawn by `hud.frag` too).
- Corners: `Theme.radiusS` / `radiusM` / `radius` / `radiusL` (all 0:
  the corners are square, and the names stay so a thing still says which
  corner it follows; README has where each goes), never a literal.
  Something drawn over a corner (a hover fill, a hairline frame, a badge,
  a busy sweep, a progress line along its foot) takes the same radius;
  `Ticks` take the control's `radius`. Panels cut one corner at 45°
  (`Theme.hudCut`). `clip` is square.
- Motion: every animation's length and curve is a `Theme` token
  (`snap`, `flicker`, `hit`, `hold`, `lock`, `fade`, `settle`, `turn` and
  its `turnCover`, `turnReveal`, `land`, `count`, `rise`, `wash`, `stagger`,
  `speak`, and the lengths in the flavour's `beat`, which are 0 for `SOL_SHOT_CALM`; `sweep`, `drift`,
  `crossing`, `scene`, `notchGlide`, `touchGlide`, which never are, since
  something loops or waits on them; the curves `ease`, `easeOut`, `spring`,
  `easeInOut`, `easeIn`, assigned whole: `easing: Theme.spring`), never a number of
  milliseconds, an `Easing.` or a SpringAnimation of its own; colours come
  from `Theme` (a world's own from its singleton). The QML lint
  (`deploy/claude/hooks/qml-lint.py`) warns of a new one; a deliberate one
  carries `// not a token: <why>` on its line or the line above. A
  component still decides what less motion (`Theme.calm`) does to it.
  Arrivals follow the flavour's `Theme.beat`; big acts (the opening, a
  turn, a moment) go anticipation, `hit`, `hold`, release; never hold input
  back for one.
- Title type: the flavour's face only from its floor up (`Theme.titleFloor`,
  per face in `titleFloors`: Makinas 18, Yuji Syuku 20, none for Corporate
  Logo and Keifont); words in it go through `Theme.titleFace(size)` /
  `titleWeight(size)` (the display face under the floor). Marks (a seal,
  the rail's diamond, Mercury's kanji numbers) may keep `fontTitle`.
- Fonts: `assets/fonts/` holds the faces and their licences (`OFL-*.txt`);
  `src/fonts.rs` and `cpp/fonts.h` register every `.ttf` and `.otf` there
  at start-up; `scripts/fonts.py` makes them. Only openly licensed faces go
  here (this repository is public). A world's own title face stays in its
  repository and is added with `sol_quick::add_font` (Neptune's Makinas 4
  may not be changed or handed on, so it is carried there as it came); the
  kit names each flavour's face (`Theme.yozoraLooks`' `title`) and falls
  back to Corporate Logo where the app doesn't carry it. A title face has
  one weight: set titles in `Theme.weightTitle`, never `Font.Bold`/`Black`,
  or Qt thickens it.
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
  `fullHeight` unless its `pins` is false (a Sheet keeps `collapse`,
  `fullHeight`, `compact`; a PageHead keeps `screen`, `reveal(dir)` and
  those three, pinning itself through `screen.pin` once it has a
  `feature`). A PageHead reads the Screen's `padded`, `composed`,
  `contentX` and `contentWidth` to line its words up with the content;
  the Screen's big title on a `sparse` page reads its header's `jpTitle`
  and `title`. Pages must not declare their
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
  `pages` for its tabs; SettingsScreen and MoonSettings read
  `Window.window.moonSettings` and the Screen's `params.part` (a
  SettingsPart's `key`; SettingsScreen finds its parts by their `key` and
  `order` among its stack's children). A PageHead with `tabs` calls
  `screen.shell.retab(params)`; AppWindow finds it among the page's
  `header` (`tabs`, `current`, `choose`) for the palette's tab rows.
- **The page turn**: `Shell.show` plays its `PageTurn` (over the pane, above the
  pages, its way `Theme.beat.turn`: `slice`, `cut`, `ink`, `sweep`) and
  `Sounds.turn()` with `in`, `up` or `back` as it calls the page's
  `reveal(dir)`; the old page nudges for a `hit` and is hidden at
  `Theme.turnCover`; the Screen keeps its content and its band out of sight
  until then (`landWait(dir)`, `turnReveal`), sets `landsAt`, which Card and
  Settle read (through `Theme.screenOf`) to start arriving as it lands, and
  calls `reveal` on its header children (PageHead, Sheet: they land after
  the same wait). A Sheet with `aside` in a window under 1300 px is
  `beside` the page: `Screen.pin` gives it no collapse and the page no top
  pad, and a first page puts its column at `Screen.startX`, `startWidth`
  wide; the Sheet's `reveal("open")` has its NeonSign `catchLight()`. A tab's own page (`retab`) is `tab`: no turn, the two
  pages only fade; `open` lands at once (the opening's last beat).
- **The opening**: the Shell makes `Opening` (z 30) and plays it as it goes
  home; it marks `AppWindow.opened` (once a run), asks the Sidebar to
  `drawIn()` (each SidebarRow's Settle `again()`) and the page to
  `reveal("open")`; the Shell's `Keys.onPressed` and the Opening's passive
  PointHandler skip it (`drawnIn()`), the event going on. AppWindow's frame
  skips its own fade-in while `Shell.opening` is true. It never plays with
  `Theme.calm`, `Sol.background`, or in `SOL_SHOT`/`SOL_SHOTS` unless the
  path has `_opening=1`. When the window was asked for a carried moon's page
  (`SolBackend.openPath`, or a staged shot's path) whose moon has a flavour of
  its own, it sets `Theme.worldId` to the moon before it plays, so the moon's
  opening (its flavour's `opening`, Luna's "moon") and sting come from the
  first frame. A star's moment (`sky.lit`) waits `Theme.settle` twice in
  AppWindow (`starLater`), so the act that lit it, and its own moment, come first.
- **Impact frames, eyecatches and title cards** (`Theme.impacts`, a
  flavour with an `impact` colour: Neptune's, Mercury's, Terra's and Luna's): the Shell sets
  `PageTurn.glyph`/`name` from the page arriving's `Screen.kanji`/`title`
  before it plays (the eyecatch), and has `impact` (Impact over its pane,
  whose `shakeX` moves the pane), which `Sol.impact` reaches through
  `Window.window`; Moment and MomentCaption become a title card. Every one
  is keyed on the flavour's own keys (`impact`, `cardInk`, `slant`,
  `steps`), so a world without them is unchanged.
- **The SSS keys** (`../../docs/yozora-sss.md`; every flavour has them all; Titan's is a
  flavour of its own with Saturn's `id`, so its stings, stills and navigator stay Saturn's; a
  light one with `duotone`, Terra's, stands on paper, `Theme.paperArt`, and its `art…` tokens
  are ink): a Grid calls its page's
  `offerRuler(grid)` as it is made and `dropRuler` as it goes, and the Screen
  draws `rules` (the widest Grid's column edges) when the flavour has
  `grid`; the Shell draws `Scaffold` over the ground, under the pages; a
  Sheet calls `reveal(dir)` on what is in its `art`, and a PageHead calls
  `reveal(dir, wait)` on its `feature` (a world's outline name draws on
  there); OutlineText's and Signature's strokes are always dashed (Qt's
  Shape doesn't take a change of `strokeStyle` once drawn) and a dash
  starts again at every outline, so the dash is a letter's length; a
  PathText's ink top, not its ascent, stands at its `y`. HudGlass's motif
  `panel` is `5` in `hud.frag`. `Shell.show` defers `accent()` by
  `Theme.turnCover` (`recolour`) when a page of another flavour arrives on
  a curtain, and plays `crossTurn` (a PageTurn over the whole window, z 20)
  instead of the pane's; PageTurn reads its colours once, in `play`.
  Theme's `onImpact` never took its value (it read black in every flavour;
  QML may take `on` and a capital for a signal's handler, here beside the
  `impact` property): it is `cardInk` now; give no new property such a name.
- **The band lines up with the rail**: `Sidebar.headHeight` (its brand
  block, from the rail's top) reaches PageHead through the Shell's
  `headHeight`, and `Shell.headTop` (the rail's inset) through
  `Screen.headInset`, which moves a PageHead (not a Sheet) and the page
  under it down to the rail's top edge. A change to the brand's height
  changes every band's.
- **The hero flight** morphs by scale: the flyer takes the landing's size
  and is scaled from where it left (Pictures are square, so it reads no
  `rounded` or `radius`).
- **Containers that place children**: Grid writes `card.index` and `card.lead` (its first), reads
  `card.span`, calls `card.glide(dx, dy)` when it has one, sets the
  `height` of cards ending level (a pair, or feet within `level`) and a
  pair's `spare` (when the card has it), and skips
  Repeaters (`Theme.isRepeater`); PageHead reads `Button.natural`;
  `Button.room` walks up to a parent with `childRoom` (Sheet sets it);
  Grid lets go of its cards' signals on destruction (a grid made by a
  Loader, a moon's settings part, otherwise warns as the app quits);
  `Theme.whenSeen` finds the nearest Flickable (`contentY`,
  `contentHeight`, `contentItem`); `Theme.screenOf` the nearest Screen.
- **`Window.window as AppWindow`**: Glass reads `backdrop`; HudGlass `shell.ground` and
  `shell.groundBlur` (a page's glass reads the one blurred ground, not the
  frame it sits in; GlassPanel's, over the pages, blurs `backdrop` live); Card,
  MenuArea and MoreButton `menu.openAt`; Key `ask.current`, `commandPalette.open`, `menu.open`;
  DeviceCard `widget`, `widgetsHere`, `widgetPrefs.*`, `widgetName`;
  `assets/widget/DesktopWidget.qml` `host.widget`, `host.widgetPrefs.corner`;
  `assets/capture/Capture.qml` `host.capturing` (it sets it false to
  close) and `host.stagedCapture`; the Shell's `?` sheet `tour`,
  `tourSheet.show()` and `allCommands` (`windowCommands`, the window's
  `commands`, its moons' and the tour, then `pageCommands`, the page's
  `Screen.actions` and other tabs; the palette takes the two apart as
  `commands` and `verbs`, with `pageName` over the verbs, and keeps what
  was run lately in the app's `sol.<world>` `paletteRecent`, never in a
  preview); the notice stack
  `shell.pageArea`; SolCard `keptAside.open`. Worlds read `menu`, `ask`,
  `keptAside`, `moment`, `shell`, `started` and set `commands`, `find`,
  `footer`, `busy`, `warn`, `tour`, `moments` (`_moment=<name>[:<arg>]`
  plays one; `stageMoment` reads the arg after the first `:`).
- **Notice's required properties** match the roles of `Notices.list`
  (`key`, `world`, `title`, `body`, `tone`, `action`, `jp`, `detail`); a delegate must not
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
- **The Yozora look** (`../../docs/yozora.md`) is the only look: the tokens in `Theme`
  are its own, and a component takes its colours, corners and type from them. A
  light flavour (`Theme.light`, Terra's noon) makes the words on glass dark: whatever
  stands on the still itself rather than on glass (the Sheet's title card, `HeroFigure`,
  the Screen's big title, `MoonLink`, `Comet`, `Moment`, `MomentCaption`, `Picture`'s
  missing-art card) takes the `art…` tokens, which over a dark flavour equal the glass's,
  so nothing changes there. The Shell sets `Theme.worldId` to the page's moon while one
  with a flavour of its own (`Theme.yozoraLooks.luna`) is open, else to the window's
  world; stills and the navigator still follow the planet (`Theme.planetOf`). The Shell picks the ground (`groundSource`:
  the page's `Screen.ground`, else `Theme.groundsOf(world)` by the section's `top`, or a
  moon's own stills, `Theme.ownGroundsOf(moon)`, counted from its first section) and
  the navigator's line (`navigatorLine` and `navigatorJp`: `Screen.say` and `sayJp`, a
  greeting on the first page, else nothing; `navigatorAway` while a page's `Empty`
  speaks beside its own portrait, which it says through `Screen.emptySay`); the
  Sidebar's `navigatorReach` (how far the frame breaks into the pane) is read
  through the Shell by a `sparse` page's big title; `Sol.cheer()` reaches every
  `NavigatorFace` through `Sol.reacted`, and AppWindow's `stagedHour` (`_hour`) is
  the hour it keeps for a picture; the Sidebar's status slot has a `room` (short of
  the navigator's head chip, `Navigator.chipEdge` at the words' height), which AppWindow's LinkStatus
  takes as its own `room`; PageHead reads the Shell's `history`
  and `rows` for its number and a section's `jp`; SidebarRow takes `jp` and `moon`. The
  bridge's `lookArt` lists `~/.local/share/sol-yozora/` at start and again
  once `look_art::fetch_missing` (spawned at start unless `SOL_SHOT`/`SOL_SHOTS`
  is set) has brought any; the names it writes (`<world>-ground-<n>.jpg`,
  `<world>-mascot.<jpg|png>`) are what `Theme.groundsOf`, `ownGroundsOf` and
  `mascotOf` read; where they come from is `core/yozora-art.json`, which
  `scripts/yozora-art.sh` reads too. Nothing in the kit or a world
  may ship those pictures.
- **Singletons written from outside**: `Theme.world` and `Theme.worldId` (Shell),
  `Theme.alive` (AppWindow), `Theme.signed` (Signature, once its name is written), `Sounds.world` (Shell) and `Sounds.pressedAt` (AppWindow), `Worlds.surfaces`
  (a world, through `Worlds.setSurface`: Terra's `green` and `cloudy`, the
  body shader's last two uniforms).
- **Settings files**: `~/.config/sol/device.conf` `[appearance] motion`
  (`full` / `less`: `Theme.calm`) (every Sol app; no app of this kit reads `mode`); the app's own
  file (name from `set_application_name` and `set_organization_domain("sachi.digital")` in `run`) with categories
  `sol.device` (`sounds`: on unless written false with `soundsVersion` 1; an older false is forgotten and written over once, `Sounds.qml`) and `sol.<world>` (`accent`, no longer read: the flavour's light
  is the accent; `widget`, `corner`,
  `toured` (the first-run tour seen); Luna's `nightSounds`, `nightVolume`;
  Neptune's `notToday`; Triton's `dj`). A preview shares the installed app's
  file: the tour writes `toured` only outside a preview.
- **The world's voice**: `Sounds.voice()` plays `assets/sounds/<Sol.world>.wav`
  for the worlds in `Sounds.voices`; a new world adds its line there and in
  `scripts/world-sounds.py`. The stings are per flavour,
  `<Theme.flavour>-turn|opening|moment.wav` (saturn, mercury, neptune,
  terra, luna): a new flavour adds its three there; `-lit.wav` (a light
  coming on, `Sounds.lit()`) only for the flavours in `Sounds.lights`
  (Neptune's, Saturn's, Mercury's, Terra's), each added last in `world-sounds.py` so the seeded
  noise of the others stays; `open`, `close`,
  `focus`, `error` are the kit's. AppWindow records presses in
  `Sounds.pressedAt` so a click's focus makes no `focus()` sound.
  `Sol.cheer()` sends `reacted("cheer")` (the big one: a jump and sparks) at
  most once in `Sol.cheerRest`, and `reacted("happy")` (the warm light)
  between, at most once in `Sol.happyRest` (20 s). A new flavour's stings
  are measured against the others (their loudness as BS.1770 has it) and
  matched by an entry in `Sounds.trims`; see `docs/yozora.md`, "Direction".
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
  `SOL_SHOT_CALM`, `SOL_FPS`, `SOL_DRIVE`,
  `SOL_CALM`, `SOL_FLAVOUR` (`<world>`: wear that world's flavour for the run), `SOL_FAKE_NAVIDROME`, `SOL_QML_LIVE`.
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
  the library and their tests change with it. Its JSON names no cover, so
  the previews show the missing-art card (Neptune's test checks that); a
  cover asked for by id is still a drawn PNG. It answers only what those
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
  re-places itself when any ancestor moves; keep that watch. HudGlass on
  the ground needs none: its vertex shader (`hud.vert`) finds where it is
  drawn on the window from the item's matrix, so it must never sit inside
  a `layer` (it would read the layer's place, not the window's); the
  uniform block of `hud.vert` and `hud.frag` must stay the same.
- Never reparent an item out of a Flickable's column (it stops rendering).
- A scale on something that may be very tall (a Card holding a long list)
  moves its far edge by a share of its height: a Card 30 000 px tall,
  scaled 3 % about its foot as it arrived, sat 900 px lower than its place,
  so `whenSeen` never found it on screen. Card, HudPanel and Lean scale a
  tall thing's height by a few pixels, not a share, about its top.
- `Lean` sees the pointer only above what it leans: it goes last inside its
  thing (its `z` is high; its handlers are passive, so the thing's own
  MouseArea still gets the click).
- A component that declares a new `default property` over its base's
  (SettingsScreen over Screen) gets its users' children there, but the
  children written in its own file still go to the base's default: put
  those inside the target item by hand. Inside an inline `Component`, a
  property of the made object hides an id of the same name outside it
  (a PageHead's `screen`): set such properties from the Loader's `onLoaded`.
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
  (`examples/gallery`, every component on four pages, once for each of the
  four flavours (`SOL_FLAVOUR`), less motion and narrow, and the focus,
  menu, palette, dialog and notice states (in Saturn's run), then
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
