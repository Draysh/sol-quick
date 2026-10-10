# sol-quick (kit/quick)

The design language in Qt Quick (the QML module `Sol.Design`, `qml/`) and
the Rust side every world app shares (`sol_quick::run` and friends, `src/`).
Every world app and `kit/template` build on it; Sol's own web app does not
(that is `kit/design`). `README.md` lists every component and module;
`docs/world-apps.md` is the guide for working in a world.

## Who sees a change here

- The worlds pin a released tag (`sol-quick = { git, tag = "v0.x.0" }`),
  so an edit reaches nothing until they point at it. `hub/scripts/worlds.sh
  use-local` points every consumer at this checkout (`path = "../../kit/quick"`);
  then `cargo build` in a world compiles this crate's QML too.
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
  `Rounded.qml`.
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
  `height`, then sets `back`, `x`, `opacity`, reads `title`, and casts to
  `Design.Screen` for `filter`, `filters`, `scrollBy`, `pageStep`, `hero`,
  `restingPoint`, `wheel`, `notch`. The Sidebar reads `filter`/`filters`.
- **The hero flight** reads `rounded` and `radius` from the item it
  flies from and the page's `hero` (a Picture has both), and turns the
  one corner into the other on the way.
- **Containers that place children**: Grid writes `card.index` and skips
  Repeaters (`Theme.isRepeater`); PageHead reads `Button.natural`;
  `Button.room` walks up to a parent with `childRoom` (Sheet sets it);
  `Theme.whenSeen` finds the nearest Flickable (`contentY`,
  `contentHeight`, `contentItem`); `Theme.screenOf` the nearest Screen.
- **`Window.window as AppWindow`**: Glass reads `backdrop`; Card
  `menu.show`; Key `ask.current`, `commandPalette.open`, `menu.open`;
  DeviceCard `widget`, `widgetsHere`, `widgetPrefs.*`, `widgetName`;
  `assets/widget/DesktopWidget.qml` `host.widget`, `host.widgetPrefs.corner`;
  the notice stack `shell.pageArea`. Worlds read `menu`, `ask`, `shell`,
  `started` and set `commands`, `find`, `footer`, `busy`, `warn`.
- **Notice's required properties** match the roles of `Notices.list`
  (`key`, `world`, `title`, `body`, `tone`); a delegate must not redeclare
  `model`.
- **Singletons written from outside**: `Theme.world` (Shell, DeviceCard),
  `Theme.picks` (Shell's Tone), `Theme.alive` (AppWindow).
- **Settings files**: `~/.config/sol/device.conf` `[appearance] mode`
  (every Sol app); the app's own file (name from `set_application_name`
  and `set_organization_domain("sachi.digital")` in `run`) with categories
  `sol.device` (sounds) and `sol.<world>` (`accent`, `widget`, `corner`).
- **Rust ↔ QML**: every `SolBackend` property, method and signal name
  (`bridge.rs`); the commands the kit's QML calls (the shared ones in
  `README.md`, plus `notify`); the events `tray`, `shortcut`, `notified`;
  the JSON of `orbit::link::Status` and `orbit::updates::Status` (Connect,
  SolCard, AppUpdates and `Sol` read their fields). `SolBackend.changed`
  (the collections) has no QML listener today; screens use `changes`.
- **Across processes**: the tray socket (abstract `sol-tray:$XDG_RUNTIME_DIR`,
  JSON lines of lowercase `Up`/`Down`, `tray.rs`); the single-instance
  socket `sol-<world>.sock` / `sol-preview-<world>.sock` with lines `show`
  and `open <path>`; the desktop file `sol-<world>`; the flags
  `--background`, `--open <path>`, `--install`, `--uninstall`, `--version`.
- **Environment**: `SOL_PREVIEW`, `SOL_SHOT`, `SOL_SHOT_AFTER`,
  `SOL_SHOT_PATH` (and its `_` keys), `SOL_FPS`, `SOL_DRIVE`, `SOL_LIGHT`.

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
  widens); a panicking command still replies. `SolBackend` subscribes to
  the link before reading its state.
- QML errors go to the journal, not stderr. `QT_QPA_PLATFORM=offscreen`
  draws neither the body shader nor glyph images: look at real windows.
  A drive's TestEvent click needs a mouse move onto the item first.
  With `SOL_DRIVE` set, `SOL_SHOT` never fires (cause not found yet): a
  drive takes its own pictures (`win.contentItem.grabToImage`) and ends
  with `Qt.quit()`, or the window stays open; a script that fails to load
  says so in the journal (`SOL_DRIVE: the script didn't load`).
- **One build at a time**, in the foreground (cxx-qt builds are heavy;
  parallel world builds crashed this machine).

## Checks

- `cargo fmt`, `cargo clippy --all-targets -- -D warnings`, `cargo test`.
- After any change here, the gallery: `scripts/gallery-shots.sh <folder>`
  builds it once (`examples/gallery`, the kit's own window with every
  component on four pages) and takes every page night and day, two narrow,
  and the focus, menu, palette, dialog and notice states, then prints what
  the journal said about the QML (nothing, or the lines). Read the
  pictures, before and after the change (a control's focus shows only
  while the window stays in front). `cargo run --example gallery` to
  try it by hand.
- Build a world (with `use-local` on) only when its own screens use what
  changed, and look at those screens; never every world's pages. A change
  to the Rust side is run by the gallery too (it calls `sol_quick::run`).

## Releasing

1. Bump `version` in `Cargo.toml` (0.x.0 for anything new); keep
   `orbit` on a released tag (`orbit = { git, tag }`), not `path`.
2. The person commits, tags `v<version>` and pushes (Draysh/sol-quick is
   public, so cargo can fetch it without credentials).
3. `hub/scripts/worlds.sh use-tags <orbit> <design> <quick>` points every
   consumer at the new tag; then each world is built, checked and
   released on its own (`hub/CLAUDE.md`).
