# Working on a world's app

Every world (Terra, Luna, Saturn, Titan, Neptune, Triton, Mercury, and a new
one made from `kit/template`) is a desktop app built the same way: Rust on
[orbit](https://github.com/Draysh/sol-orbit)'s `Link` for the data, QML from
this kit's `Sol.Design` for the screens, and `sol_quick::run` for the
window, the connection to Sol, installing and updating. This is the guide
they share; each world's own `CLAUDE.md` adds only what is its own (its
modules, its moon or planet, its preview data, its quirks).

Paths like `../../kit/orbit/docs/protocol.md` are relative to a world's
folder in the workspace checkout (`~/Projects/sol`); on GitHub they are
the `sol-orbit`, `sol-quick` and `sol` repositories.

## What Sol and a world are

Sol (the hub, `../../hub`) is the one server and keeps every world's data;
a world's app pairs with it, like a music player with Navidrome, keeps a
local copy that works offline, and syncs by itself. The protocol is
`../../kit/orbit/docs/protocol.md`; the design language is
`../../kit/design/DESIGN.md` (its principles, anatomy and writing rules
apply here; its colours don't: the apps' palette, a night tinted by the
world rather than pure black, is `../../kit/quick/qml/Theme.qml`) and the
kit's components are listed in `../../kit/quick/README.md`.

## The layout of a world

```
Cargo.toml        the version (tag releases v<version>); orbit and sol-quick on tags
sol-world.json    the manifest: id, name, tagline, role, repo, parent (a moon),
                  collections, emits, actions, settings, connections
build.rs          the app's QML module Sol.<World>: every qml/*.qml
src/main.rs       the Commands table and the World handed to sol_quick::run
src/world.rs      the world's logic (src/world/*.rs for the rest)
qml/Main.qml      the AppWindow: sections, pages, the window's own wiring
qml/<World>.qml   the world's singleton: state and words the screens share
qml/*Page.qml     one Screen per page; other files are the pieces they share
sample.json       preview data, where a world keeps it outside main.rs
scripts/          icon.sh, install-local.sh, signing-key.sh
update.pub        the key release files are signed with
```

- **`main.rs`** stays a table: the argument structs, `commands.add("name",
  |link, a: Args| async move { world::thing(&link, a).await.map_err(say) })`
  for each command the screens call, then `sol_quick::run(World { manifest,
  update_key, version, bin, icons, handler, commands, main, sample, prepare,
  tray, shortcuts })`. The logic lives in `world.rs` and `world/`.
- **`world.rs`** holds the collections, the events (each with a
  one-sentence summary), the `Handler` (what it does for each action in
  `sol-world.json`, and `widget.toggle`), the widget for Sol's overview,
  and the views the commands return. A test `the_manifest_is_sound` parses
  `sol-world.json` and checks its `problems()` and the actions and events
  the code uses.
- **The QML**: `Main.qml` is an `AppWindow` with `world`, `sections`,
  `pages` (path → Component; a path not in the sections is a page opened
  from another, e.g. `/title`), `search`, `shortcuts`, and as needed
  `commands`, `find`, `footer`, `busy`, `warn`, `widget`, `widgetName`.
  State the screens share lives in the singleton `qml/<World>.qml`
  (`pragma Singleton`, `import Sol.Design`); every file that uses it
  imports `Sol.<World>`. The first page starts with a `Sheet` in its
  `header`, other pages with a `PageHead`; everything else is `Card`s in a
  `Grid`. One `primary` button per screen. The Settings page has
  `SolCard`, `DeviceCard`, `SettingsCard` and `AppUpdates` (and
  `WithPlanet` for a moon).

## Data goes through the Link

The screens never talk to Sol; they call the app's commands
(`Sol.call("name", args)`, a promise), and the commands use
`orbit::link::Link`:

- Documents: `list_as::<T>(collection)` (rows of another shape are
  skipped), `list_with_ids`, `get_as::<T>(collection, id)`, `put_as(collection,
  id, &value)` (keeps an `f32` as written), and the raw `list`, `get`,
  `put`, `delete`. `orbit::doc::value_of(&v)` is the f32-safe `to_value`,
  for event data too.
- Events and widgets: `emit` (an event other worlds' connections hear),
  `push_widget`, `remove_widget`.
- Settings: `settings()` reads the world's settings as set in Sol;
  `link.on_settings(|why| async move { … })` calls back first
  (`Configure::Start`) and on every change (`Settings`, `Status(..)`,
  `Lagged`), so an engine set up from the settings follows them. Spawn it
  on the runtime handle `prepare` is given: `tokio.spawn(link.on_settings(…))`.
- Time: the person's zone is `link.time_zone()`, never the machine's.
  "Today" for a world with a `day_starts` setting (Terra, Luna, Mercury)
  is `orbit::clock::Clock::of(&link).await.today()` (or `Clock::with`
  when the settings are already read; `day_of`, `at`, `start_of`,
  `parse_time`, `time_setting` are there too). A world without one
  (Saturn, Titan, Neptune, Triton) uses the zone alone.
- The screens learn of changes through `Sol.changes` (documents, here or
  on another device) and `Sol.settingsVersion`; a world's own news to its
  screens goes out with `sol_quick::emit(name, &data)` and arrives as
  `Sol.onEvent(name, data)`.
- Errors reach the screens as one sentence: `.map_err(sol_quick::say)`
  (it keeps the causes, `{:#}`); don't write a local `say` with
  `to_string()`.

## The kit's helpers: use these, don't write your own

**Rust** (`sol_quick::…`):

- `data_dir(world)` (the local copy, the window's state, `seen/`) and
  `cache_dir(world)` (what can be fetched again: pictures, covers, spoken
  words; `~/.cache/digital.sachi.sol.<world>`, the preview's own folder
  under `SOL_PREVIEW`).
- `Shared<T>` and `handler(…)` for a world with an engine built in
  `prepare`:

  ```rust
  static ENGINE: sol_quick::Shared<Engine> = sol_quick::Shared::new();
  // commands: world::today(&ENGINE.get()).await
  handler: sol_quick::handler(|| world::World(ENGINE.get())),
  prepare: Some(Box::new(|link, tokio| { ENGINE.set(Engine::new(link.clone())); /* tokio.spawn(…) */ })),
  ```

- `say`, `emit`, `device_name`, `runtime()` (the link, the runtime handle,
  `preview`), `quit`.

**QML** (`Sol`, `Format`, `Theme`, components):

- `Sol.fail(title, why)`: a failure as a notice from this world.
- `Sol.same(a, b)`, `Sol.update(item, "name", value)` (assigns only when
  it says something new, so nothing redraws for nothing).
- `Sol.fill(item, "name", command, args, then)`: what this device saw
  last at once on a cold start, then the fresh reply; `Sol.fetch(first,
  command, args, use)` the same for a callback; `Sol.callSeen` underneath.
- `Sol.sync(model, rows, key)` (a ListModel brought to rows by a key, in
  place, from the first row that differs) and `Sol.follow(model, rows,
  keyOf, role)` (rows moved and updated in place, for a `dynamicRoles`
  model under a Grid).
- `Format`: `plural`, days as `YYYY-MM-DD` read at noon (`dayOf`, `toDate`,
  `addDays`, `weekday`, `dayNumber`, `short`, `long(day, year)`, `month`,
  `date`), times from now (`when(time, "week" | "yesterday")`, `ago`,
  `until`) and durations (`hours`, `hm`, `length`, `duration`, `total`,
  `timer`, `timeOfDay`). Each one's comment shows its output.
- `AppWindow { onStarted: <World>.start() }`: once paired (at once in
  preview), not again when the app goes offline and back. Don't wire start
  to `Sol.onStatusChanged`.
- `Theme.wheel(event, notch)` (`{ notched, x, y }`: a mouse wheel's
  notches or a touchpad's pixels), `Theme.screenOf(item)` (the page an
  item is on, to hand it a wheel event), `Theme.keepInView`,
  `Theme.typing(item)`, `Key` for a page's own keys.
- `Picture` (`url`, or `key` in a `store`) with a `PictureStore`
  (`command`, `args: key => ({ … })`, `keep` to remember files between
  runs) for pictures fetched to disk once; `Poster` for a network cover.
  Both have `Theme.radiusM` corners (`radius`: `radiusS` for a thumbnail,
  `Theme.radius` for a big cover, 0 for a backdrop that fills a band);
  a frame, veil or badge drawn over one takes the same radius.
- Corners come from `Theme.radiusS` / `radiusM` / `radius` / `radiusL`,
  never a literal (the scale and where each goes are in the kit's README).
- `Strip` for anything that scrolls sideways; `Settle` for anything that
  arrives in a list; `Skeleton` for a page's shape while it loads;
  `Chart`, `DataRows`, `Display` for figures.

## Moons

A moon (Luna, Titan, Triton) names its planet in `sol-world.json`
(`parent`) and runs whenever its planet does, without a window: the
planet's `sol_quick::run` starts the installed moons (`orbit::moons`) and
the moon leaves a little after the planet closes. The moon's Settings page
has `WithPlanet` (the shared `with_planet` / `set_with_planet`). Each
lists the connections to and from its planet in its manifest. In the
sidebar, the doors (`Sol.doors`) lead to Sol and to the kin installed
here; a Sheet's moon links come from `Sol.moons`.

## The manifest must match the code

`sol-world.json` says what the world keeps, emits, does and reads: every
event the code emits, every action its handler takes, every setting it
reads, with their meanings. Sol reads it when the world is installed;
the hub keeps hand copies in `../../hub/catalog/<world>.json`, so copy it
there whenever it changes (`hub/CLAUDE.md` has the loop). Additions with
defaults are fine; changing what a field means breaks released apps.
`role` (what the app is for, in a word or three) shows in the app menu and
the tray, and matches the world's entry in the kit's `Worlds.qml`.

## Versions and releases

- The version lives in `Cargo.toml`; a release is tagged `v<version>`.
  orbit and sol-quick are pinned to released tags; `../../hub/scripts/worlds.sh
  use-local` points every repository at the local kit for working on both,
  and `use-tags <orbit> <design> <quick>` back before committing.
- Release files are named `sol-<world>-<version>-linux-x86_64.tar.gz`
  (one file, `sol-<world>`, an AppImage), with `<file>.sig` beside it and
  `sol-world.json`; Sol offers an update only for that name shape with a
  signature (`../../kit/orbit/docs/protocol.md`, "Versions and updates").
  `../../hub/scripts/build-linux.sh <world>` builds it into `out/`; signing
  and uploading are the person's (`hub/CLAUDE.md`). The names in
  `.github/workflows/release.yml` must stay as they are.
- Installing and updating are orbit's (`install`, `updates`) and the
  `AppUpdates` card; `--install`, `--uninstall`, `--version`,
  `--background` and `--open /page?key=v` are the app's flags.
- No commits, tags or releases unless the person asks.

## Preview, screenshots, the journal

- `SOL_PREVIEW=1 cargo run`: the app with sample data on a throwaway copy
  (`/tmp/sol-preview-<world>`, filled the first time by `World::sample`;
  delete the folder for fresh data). Keep the sample current when a
  command changes. To see the person's real library, copy
  `~/.local/share/digital.sachi.sol.<world>` into the preview folder and
  `touch sampled` there (never write to the real one).
- A picture: `SOL_PREVIEW=1 SOL_SHOT=<png> SOL_SHOT_AFTER=6000
  SOL_SHOT_PATH='/page?key=v' ./target/debug/<bin>`; `_palette=1`,
  `_notice=1`, `_ask=1`, `_notify=1`, `_scroll=N` stage it;
  `QT_SCALE_FACTOR=3` shows the narrow layout. It opens a real window for
  a few seconds: run them one after another. Read the picture.
- QML errors go to the journal: `journalctl --user -S "<start>" |
  grep '<bin>\['` must show no TypeError, ReferenceError, "Cannot assign",
  "Unable to assign" or binding loop from your code.
- `SOL_DRIVE=<file.qml>` loads a script handed the window (`property var
  win`), to drive it end to end; it takes its own pictures and must end
  with `Qt.quit()` (`SOL_SHOT` doesn't fire alongside it). `SOL_FPS=1`
  counts the frames painted.

## Checks

- `cargo build` (it compiles the QML: a bad `.qml` fails here).
- `cargo fmt && cargo clippy --all-targets -- -D warnings && cargo test`
  (Neptune: `--workspace`).
- Screenshots of every page in `Main.qml`'s `pages`, one detail page, and
  the journal, before and after a change.
- A change to the kit is checked in the kit's gallery
  (`../../kit/quick/scripts/gallery-shots.sh <folder>`, one build), not
  by sweeping the worlds; a world is looked at only when its own screens
  use what changed.
- One build at a time, in the foreground: never two worlds at once.
