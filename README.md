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

```toml
[dependencies]
sol-quick = { git = "https://github.com/Draysh/sol-quick", tag = "v0.3.0" }   # or path = "../../kit/quick" (worlds.sh use-local)
cxx-qt = "0.10"
[build-dependencies]
cxx-qt-build = { version = "0.10", features = ["link_qt_object_files"] }
```

`build.rs` declares the app's own QML module (`Sol.<Name>`, every file in
`qml/`), and `main.rs` hands `sol_quick::run` a `World`: the manifest, the
update key, the icons, the `Handler` for what Sol asks of the app, the
`Commands` its screens call, and the URL of `Main.qml`. The template in
`kit/template` is the smallest complete example; `cargo build` compiles the
QML too, so a mistake in a `.qml` file fails the build.

Needs Qt 6.12 or later: `qt6-base`, `qt6-declarative`, `qt6-shadertools`
and `qt6-multimedia` (the kit's own sounds use it, so every world does).

## The Rust side (`src/`)

| File | What it does |
| --- | --- |
| `lib.rs` | Re-exports: `run`, `World`, `Prepare`, `Sample`, `Commands`, `say`, `data_dir`, `cache_dir`, `device_name`, `emit`, `quit`, `leave`, `runtime`, `Shared`, `handler` |
| `app.rs` | `run` (command line, one copy at a time, the tokio runtime, the `Link`, moons, the tray, then the window), `World`, `Runtime`, `data_dir`, `cache_dir`, `emit`, `quit`, `leave` |
| `shared.rs` | The commands every world's screens can call besides their own (below) |
| `seen.rs` | What pages last showed (`Sol.callSeen`), a file per key in the data folder's `seen/`, pruned after 30 days |
| `autostart.rs` | Starting with the computer: `~/.config/autostart/sol-<world>.desktop` for the installed copy |
| `commands.rs` | `Commands` (typed async commands by name; replies go to JSON text, so an `f32` stays as written) and `say` (an error as one sentence with its causes, `{:#}`) |
| `engine.rs` | `Shared<T>` (a world's engine, built in `prepare` and read by commands and the handler) and `handler(|| …)` (a `Handler` made for each call, around that engine) |
| `bridge.rs` | `SolBackend`, the one QObject the QML side talks to (properties, `call`, signals) |
| `single.rs` | One copy at a time: the socket `sol-<world>.sock` (`sol-preview-<world>.sock` in preview) and its knocks (`show`, `open <path>`) |
| `tray.rs` | One Sol tray for every Sol app here (the first one hosts it; the others join over a socket) and the counts on the apps' icons |
| `desktop.rs` | Notifications (`notify`), and global shortcuts through the desktop's portal |

**The shared commands** (`shared.rs`): `connect {server}`, `cancel`,
`forget`, `settings`, `open_in_sol`, `doors` (the worlds installed here),
`open_world {world, path?}`, `notify {title, body?, action?: [id, label]}`,
`check_updates`, `install_update`, `set_auto_update {auto}`, `restart`,
`install_app`, `autostart` (null when this copy can't), `set_autostart {on}`;
and for a moon, `with_planet` and `set_with_planet {on}`. They are added
after the world's own, so a world command with one of these names is
replaced: don't use them.

**Environment** (the review hooks and switches):

| Variable | What it does |
| --- | --- |
| `SOL_PREVIEW` | The Shell without pairing, on a throwaway copy (`/tmp/sol-preview-<world>`) filled with sample data the first time; its own socket, so it runs beside the installed app. On with any value, even `0` |
| `SOL_SHOT=<png>` | A picture of the window after `SOL_SHOT_AFTER` ms (2500 unless set), then the app quits |
| `SOL_SHOT_PATH=/page?key=v` | The page to open first, with its params; keys starting with `_` stage the picture: `_notice=1` (a notice), `_ask=1` (the dialog), `_notify=1` (a desktop notification), `_palette=1` (the command palette), `_scroll=N` (the page scrolled to N, 1.8 s in) |
| `SOL_FPS` | The frames really painted each second, in the journal (0 while nothing moves). On with any value |
| `SOL_DRIVE=<file.qml>` | A script loaded into the window (handed `win`) that drives it end to end |
| `SOL_LIGHT=night\|day` | This run's light, whatever the device's setting says |
| `QT_SCALE_FACTOR` | Qt's own: `1.5` to check fractional scaling; a large one (3) also makes a narrow window |

## The QML module (`qml/`, `Sol.Design`)

Every `.qml` file in `qml/` is registered (no `qmldir`); one whose leading
lines include `pragma Singleton` is a singleton. `import Sol.Design` in a
world's files; inside the kit and in a world, `import Sol.Design as Design`
for `Design.Screen` (Qt has a `Screen` of its own).

**Singletons**

- `Theme`: every token (the sky in three depths, night and day, type,
  spacing, corners, durations, eases) and the rules the controls share:
  `whenSeen(item, arrival)`, `wheel(event, notch)`, `screenOf(item)`,
  `keepInView(flick, top, height)`, `typing(item)`, `isRepeater(item)`,
  `chosenAccent` (this device's accent, `sol.<world>`), `mark(c)`, `tint(c, a)`.
- `Sol`: the connection as the screens see it (`status`, `paired`,
  `online`, `unsent`, `changes`, `settingsVersion`, `app`, `manifest`,
  `preview`, `background`), `call` and `callSeen`, and the helpers every
  world shares: `fail`, `same`, `update`, `fill`, `fetch`, `sync`,
  `follow`, `badge`, `openUrl`, `openInSol`, `openWorld`, `doors`, `moons`,
  `clock`, and the `event(name, data)` signal.
- `Format`: counts, days, times and durations as words (`plural`, `dayOf`,
  `toDate`, `addDays`, `weekday`, `dayNumber`, `short`, `long`, `month`,
  `date`, `when`, `ago`, `until`, `hours`, `hm`, `length`, `duration`,
  `total`, `timer`, `timeOfDay`); each documents its output.
- `Worlds`: every world's name, role, tagline, colour, tilt, photo, kin
  (moons and planets), and the real sky (`skyOf`, `moonAt`, `now`).
- `Notices`: in-app notices (`show`, `dismiss`, `failed`).
- `Sounds`: `tick`, `done`, `off`, once turned on in `DeviceCard`.
- `SolBackend` (Rust, `bridge.rs`): what `Sol` and `AppWindow` are built on.

**The frame**

- `AppWindow`: a world app's window: Connect until paired, then the Shell
  with the app's `sections` and `pages`; `menu`, `ask`, `commandPalette`,
  `commands`, `find`, `footer`, `busy`, `warn`, `widget`, `widgetName`, and
  `started()` (the moment to start the app's own work: once paired, at
  once in preview; not again on an offline/online flip).
- `Shell`: the sidebar and the pane, history and the way back (a page
  opened from another has one, a section opened with params from another
  page too), the keys, the hero flight (`go(path, params, { item, url })`).
- `Sidebar` (the Shell's own, with `SidebarRow` for sections and doors).
- `Screen`: a page in the pane (`header`, `filter`/`filters`, `hero`,
  `scrollBy`, `wheel(event)`, `notch`, `pageStep`).
- `PageHead`: a working page's toolbar (title, a quiet line, actions, the
  way back, `editable`).
- `Sheet`: the band across a world's first screen, pinned and shrinking.
- `Back`: the way back, by name (Space or Enter from the keys).
- `Connect`: pairing; `LinkStatus`: the sidebar's bottom line; `Waiting`:
  a small spinner while the status is unknown.

**Panels**

- `Card` (a raised panel with a title; `menu` on right-click), `Grid`
  (cards in auto-fit columns), `Callout` (a dotted leader and a short
  list, in a Sheet).
- The Settings cards every world has: `SolCard`, `SettingsCard`,
  `DeviceCard`, `AppUpdates`, and `WithPlanet` for a moon.

**Controls**

- `Button` (`primary` once a screen, `ghost`, `quiet`, `round`), `Chip`,
  `Check` (optimistic, `fail()`), `Toggle`, `Slider`, `Field`, `TextArea`
  (`large` for writing at length, `single` when Enter goes on), `Select`,
  `Editable`, `MoonLink`.
- `Key`: a key for one page (quiet while you type, or while a menu, dialog
  or the palette is open).

**Overlays** (on the window, over the pages, on glass)

- `ContextMenu` (one per window: `win.menu`), `CommandPalette` (Ctrl+K),
  `Ask` (`win.ask.name(…)`, `win.ask.confirm(…)`), `Hint`, `Notice` (made
  by the window from `Notices.list`), `Shortcuts` (`?`).
- `Glass` (the pages behind, blurred and bent, cut to its `radius`; `from`
  blurs another item, as pairing does) and `GlassPanel` (glass with a
  hairline and `Theme.radius` corners: what the overlays sit on).

**Display**

- `Display` (a figure that counts up), `DataRows` (`Label: value`),
  `Progress`, `Chart`, `Skeleton` (a page's shape before its data).
- `Picture` (a picture from a `url`, or a `key` in a `PictureStore`:
  `ratio`, `crop`, `outline`, `lift`/`hovered`, `dim`, `animated`, the name
  in its place, a fade, a retry when a file has gone, `radius`), `PictureStore` (a
  world's pictures fetched once to disk by one of its commands), `Poster`
  (a Picture for a network cover, 2:3, outlined).
- `Strip`: a row that scrolls sideways (sideways wheel, swipe or Shift;
  the vertical wheel goes to the page), a hairline showing where you are,
  `fades` at the ends.
- `Body` (a world's photo on a sphere lit by a shader: its place in the photo, `fit`, and its `air` are in `Worlds`), `Reticle`, `WorldGlyph`,
  `Icon`, `Tone` (a picture's colour), `Spark` (a burst for a moment that
  earns one).
- Text: `Heading`, `Label` (uppercase, small, bright), `Quiet` (uppercase,
  small, quiet), `Words` (reading text, `quiet`, `small`, `jp`).

**Primitives**: `Ticks` (the focus mark, rounded with what it marks:
`radius`), `Rounded` (an image's picture with rounded corners, cut in a
shader: what Picture and the flying hero draw with), `Settle` (arrive when
seen, a stagger apart), `Underline` (a field's line and its focus light),
`Caret` (the text cursor), `Grain`.

**Assets** (`assets/`, in the module's resources): the fonts (Outfit,
Shippori Mincho), every world's photo (`worlds/`), the sounds (`sounds/`,
generated WAVs), `grain.png`, `sol-tray.png` (the tray's icon), and
`widget/DesktopWidget.qml`, loaded by URL from outside the compiled module
(it imports `org.kde.layershell`, which may be missing). **Shaders**
(`shaders/`): the body's lighting, the glass and the rounded picture
(`picture.frag`, Rounded's), committed as `.qsb`; after changing one, from
`shaders/`:

```sh
for f in body glass picture; do /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o $f.frag.qsb $f.frag; done
```

## Writing a screen

A page is a `Screen` (a `PageHead` in `header`, cards below), the first one
a `Sheet`. State the screens share goes in the world's own singleton
(`qml/<Name>.qml`, `pragma Singleton`), which every file that uses it
imports with `import Sol.<Name>`. Lists are `Repeater`s whose delegates are
`Settle`d. What the design kit's `DESIGN.md` says about words, spacing and
motion holds here unchanged; [DESIGN.md](../design/DESIGN.md) has the QML
notes.

Light and depth differ from the web's pure black, for long sessions in an
app: the window is a night sky in three depths, and colour still comes only
from the worlds.

| Token | What it is |
| --- | --- |
| `Theme.deep` | The chrome: the sidebar, a `Sheet`'s band and strip, a `PageHead` |
| `Theme.space` | The pane, where the work is: `night` (`#0c0e13`) tinted 5 % by the world's own colour, so each app has its own sky |
| `Theme.raised` / `raisedTop` | A panel off the pane: every `Card` is one, lit a little from above, with `Theme.radius` corners and a hairline |
| `Theme.textWorld` | A panel's title, in the world's light, over a hairline that splits head from body |

Corners come from one scale, so nothing sits square on a rounded panel;
an inner corner is about the outer one less the room between them (a
menu row's light, inset 4 px in a 10 px panel, is 6). Pills (a `round`
button, a switch, a count) stay pills; hairlines, rules and the month's
grid lines stay straight.

| Token | Value | Where |
| --- | --- | --- |
| `Theme.radiusS` | 4 | A `Check`'s box, a `Skeleton`'s lines, a `Chart`'s bars, the pairing code, an `Editable`'s or a link's focus ticks; worlds: badges inside a picture, Terra's week ticks, thumbnails under 48 px |
| `Theme.radiusM` | 6 | `Button`, `Chip`, `Back`, a `Picture` (posters, covers, stills), a menu's, list's or palette's row light, a `SidebarRow`, a `Chart`'s tip; worlds: tiles, kana cells, Saturn's watched tick, a lifted queue row |
| `Theme.radius` | 10 | `Card`, every `GlassPanel` (menus, the `Select` list, `Hint`, `Notice`, the palette), the pairing card's glass; worlds: a big cover or poster, Saturn's continue card, Titan's galaxy, Saturn's month |
| `Theme.radiusL` | 14 | Big surfaces on their own: `Ask`'s dialog, the `Shortcuts` sheet, the desktop widget |

The web kit's `DESIGN.md` says groups get corner ticks, not boxes; the Qt
kit raises its groups as rounded panels instead, and keeps the ticks for
focus and for a card under the pointer, bent round the corner they mark.

Text has a hierarchy: a fact's label is quiet (`textQuiet`), its value is
bright (`text`), reading text is softer (`textValue`), and `textBright` is
for names. Every world has a `role` (`Worlds.qml`, and `sol-world.json` for
the app menu): what it is for in a word or three, shown under its name in
the sidebar, in its doors and moon links, in the window title, the tray
and the app menu ("Terra · Habits and diary").

Things QML's JavaScript lacks or forbids, found the hard way: no
`Array.flat`/`flatMap` (use `reduce` and `concat`); no `Promise.finally`
(`Sol.qml` adds it); an `Item` can't take a custom property called `data`,
`enabled`, `top`, `right` or `y`; `target: parent` inside an animation is
undefined (use an id); a `Repeater`'s delegate must be an `Item` (use an
`Instantiator` for `Shortcut`s or `ShapePath`s); no anchors inside a `Flow`;
`required property int index; index: index` binds the property to itself
(always 0); Qt 6 has no `Glow` (a `MultiEffect` shadow with no offset is
one); and on Wayland Qt fills `pixelDelta` for a mouse wheel too, so only
`event.phase === Qt.NoScrollPhase` tells a wheel from a touchpad
(`Theme.wheel` does it).

## The gallery

`examples/gallery` is the kit in its own window: every part of
`Sol.Design` on four pages, as Shell sections, with sample data and the
kit's own photographs. **Worlds**: the window's world's Sheet (each world
in turn, ← and →), every Body at 22, 48, 120 and 300 px, every
WorldGlyph. **Controls**: every Button variant resting, busy and off,
Chip, Check (on, off, busy, failing), Toggle, Slider, Field (empty,
typed, invalid), TextArea (and `large`), Select, Editable, Back,
MoonLink, a page's `Key`, Ticks. **Panels**: Card in its ways, Grid at
three widths, DataRows, Display, Progress, Callout, Settle, every
Skeleton and Chart, Strip, Picture and Poster (loaded, missing, dim,
lifted). **Overlays**: ContextMenu, CommandPalette, Ask, notices, Hint.

```sh
cargo run --example gallery          # by hand: a preview, no Sol, no network
scripts/gallery-shots.sh /tmp/shots  # after a kit change: one build, every page night and day, the journal
```

Its QML (`examples/gallery/qml/`) is read from this checkout when it
starts, so changing it needs no build; the kit's own QML is the compiled
module, as in a world. It is an example, so the worlds get nothing from
it. Besides the usual `_` keys, its shot path takes `_world=saturn` (the
window as that world), `_focus=field` (`button`, `field`, `textarea`,
`slider`, or `select` with its list open) and `_menu=1` (the menu open on
Overlays).

## Checking a screen

```sh
SOL_PREVIEW=1 SOL_SHOT=/tmp/today.png SOL_SHOT_AFTER=2500 SOL_SHOT_PATH=/ cargo run
journalctl --user -S -1min | grep '<world>\['     # QML runtime errors land here, not on stderr
```

`SOL_SHOT_PATH` takes a page's params as a query (`/title?key=x`), and the
`_` keys above stage a notice, the dialog, the palette or a scroll. A
change to the kit itself is looked at in the gallery (above), not in
every world.

## The desktop around the window

- **One Sol tray** (`src/tray.rs`): the first Sol app to start shows a
  single Sol icon; the others join it, each as a submenu (Open, the entries
  a world lists in `World::tray`, Quit), and the next takes over when it
  quits. Closing a window hides it while the tray is there.
- **Counts**: `Sol.badge(10, "due")` puts a count beside the app in the
  tray, in its tooltip, and on its icon in docks that read the Launcher
  Entry API.
- **Desktop widgets**: a world sets `widget` (a Component) and
  `widgetName` on its `AppWindow`; Settings → On this device shows it on
  the desktop (a layer-shell panel in a corner, under the windows) while
  the app runs. Wayland with layer-shell-qt only; elsewhere nothing shows.
- **Start with the computer**: the installed copy can start at login in
  the tray, without a window (`autostart` / `set_autostart`).
- **Notifications**: `notify` shows one with an optional button; what was
  pressed comes back as a `notified` event (Terra's reminders tick the
  habit from one).
- **Global keys**: `World::shortcuts` binds them through the desktop's
  portal and sends a `shortcut` event on each press; the desktop may ask
  to confirm them the first time. Neptune's MPRIS (media keys, the
  desktop's player widget) lives in its audio crate.

## Night and day, the sky, charts, instant start

- **Night and day**: `Theme.day`, from Settings → On this device ("As the
  desktop is", "With the sun", always night, always day) for every Sol app
  on the computer (`~/.config/sol/device.conf`). Overlays use `Theme.ink`
  at an alpha (white at night, black by day), dims and glass `Theme.veil`.
  A world's colour as a small mark (a glyph, the current section's light,
  the chosen row) is `Theme.mark(c)` / `Theme.accent`: deepened by day,
  so a white moon still shows on the pale sky.
- **The real sky**: Luna shows tonight's phase and Terra's light follows
  the local hour wherever a body is drawn (`Worlds.skyOf`, `Worlds.moonAt`).
- **Charts**: `Chart` draws bars or lines for one or more series over the
  same labels, grows in when seen, and says the exact values under the
  pointer.
- **Instant start**: `Sol.callSeen(command, args, use)` hands a page what
  it showed last time on this device at once, then the fresh reply; kept
  in the app's data folder (`seen/`), written only when it changed.
  `Sol.fill(item, name, command)` does it for one property.

## The palette and the hero

Ctrl+K opens the **command palette** (`CommandPalette`): the sections, the
window's `commands`, and what its `find` turns up as you type (Saturn
searches titles, Neptune the library, Mercury the dictionary).
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
on `fail()`; a `Card` with a `menu` opens it on right-click. `Skeleton`
draws a page's shape while its data is on the way. `Sounds` (off until
turned on in `DeviceCard`, which also picks the world's accent from its
photograph) gives a tick, a done and an off. Fractional scaling works as
Qt does it: `QT_SCALE_FACTOR=1.5` to check.

## Motion

Every screen settles into the pane and settles again when the Shell comes
back to it; the page it replaces fades under it. Lists arrive with the
stagger, bars grow from their baseline, figures count up, the first screen's
band drifts with the scroll and breathes while it waits, the main action's
glow breathes too, a card's ticks answer the pointer, and menus, notices,
hints and the dialog sit on real glass, the page blurred behind them and
bent a little at the panel's edge. The worlds are alive: clouds drift over
Terra, Neptune and Titan, Sol's corona flickers, their rims of air breathe
(`live` in `Worlds`, `time` in the body shader). Switches and the sidebar's
light move on springs. Most durations are `Theme`'s (`fade`, `lock`,
`settle`, `rise`, `drift`, `stagger`); a few controls keep their own where
they measured better (a button's glow and press, a check's tick, a wheel
notch's glide and bounce, a notice's drop, a hint's wait, the caret's
blink, a skeleton's sweep, the spinner). Nothing moves without saying what
changed, and nothing loops while the window is hidden or behind another
(`Theme.alive`). `SOL_FPS=1` writes the frames painted a second to the
journal: 170 on a 170 Hz screen.

Look at the picture before calling a screen done, and read the journal: a
binding that fails leaves a card empty without a word on the terminal.
