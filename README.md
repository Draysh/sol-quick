# sol-quick

**The Sol design language as a Qt Quick module, and the Rust side every
world app shares.** A world's desktop app is a Cargo binary: its own logic
in Rust on [Orbit](../orbit)'s `Link`, its screens in QML built from this
crate's `Sol.Design` module, and the window, the connection to Sol,
installing and updating all from `sol_quick::run`. No webview, no Node: the
screens are drawn by Qt's scene graph with real blur, shaders and glows.

## Using it

```toml
[dependencies]
sol-quick = { path = "../../kit/quick" }   # or git = "https://github.com/Draysh/sol-quick", tag = "…"
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

Needs Qt 6.12 or later: `qt6-base`, `qt6-declarative`, `qt6-shadertools`,
and `qt6-multimedia` for a world that plays sound.

## What is in it

- **`src/app.rs`**: `run`, the `World`, the shared commands (status,
  connect, forget, settings, updates, install, doors, moons), preview mode
  (`SOL_PREVIEW=1` runs against a throwaway copy with sample data) and the
  screenshot hook (`SOL_SHOT=<png> SOL_SHOT_AFTER=<ms> SOL_SHOT_PATH=<path>`).
- **`src/commands.rs`**: typed async commands the screens call through
  `Sol.call(name, args)`, which returns a promise.
- **`src/bridge.rs`**: the `SolBackend` singleton the QML side talks to.
- **`qml/`**: the `Sol.Design` module. `Theme` (every token), `AppWindow`
  (the window: Connect until paired, then the `Shell`), `Screen`,
  `PageHead`, `Sheet` and `Body` (the world's photo, lit by a shader),
  `Card`, `Grid`, `Button`, `Field`, `Select`, `Toggle`, `Check`,
  `TextArea`, `Slider`, `DataRows`, `Progress`, `RingGauge`, `Display`,
  `Chip`, `Callout`, `Hint`, `Notices`, `ContextMenu`, `Ask`, `Glass` (real
  blur of the pages behind a menu, a notice, a hint or a dialog), `Settle`
  (the stagger every list arrives with), `Poster`, `WorldGlyph`, `Icon`,
  `SolCard`, `AppUpdates`, `SettingsCard`, `WithPlanet`, `Widget`.
- **`assets/`**: the fonts (Outfit, Shippori Mincho) and every world's
  photo; **`shaders/`**: the body's lighting, compiled with `qsb`.

## Writing a screen

A page is a `Screen` (a `PageHead` in `header`, cards below), the first one
a `Sheet`. State the screens share goes in the world's own singleton
(`qml/<Name>.qml`, `pragma Singleton`), which every file imports with
`import Sol.<Name>`. Lists are `Repeater`s whose delegates are `Settle`d.
What the design kit's `DESIGN.md` says about words, spacing and motion holds
here unchanged; [DESIGN.md](../design/DESIGN.md) has the QML notes.

Things QML's JavaScript lacks or forbids, found the hard way: no
`Array.flat`/`flatMap` (use `reduce` and `concat`); no `Promise.finally`
(`Sol.qml` adds it); an `Item` can't take a custom property called `data`,
`enabled`, `top`, `right` or `y`; `target: parent` inside an animation is
undefined (use an id); a `Repeater`'s delegate must be an `Item` (use an
`Instantiator` for `Shortcut`s or `ShapePath`s); no anchors inside a `Flow`;
and Qt 6 has no `Glow` (a `MultiEffect` shadow with no offset is one).

## Checking a screen

```sh
SOL_PREVIEW=1 SOL_SHOT=/tmp/today.png SOL_SHOT_AFTER=2500 SOL_SHOT_PATH=/ cargo run
journalctl --user -S -1min | grep '<world>\['     # QML runtime errors land here, not on stderr
```

`SOL_SHOT_PATH` takes a page's params as a query (`/title?key=x`), and
`_notice=1` or `_ask=1` put a notice or the dialog in the picture.

## The desktop around the window

`sol_quick::desktop` (Linux): every app sits in the **tray** with Open and
Quit, plus the entries a world lists in `World::tray` (Neptune puts the
transport there); closing the window hides it, the tray's Quit ends it. A
`notify` command shows a **desktop notification** with an optional button;
what was pressed comes back as a `notified` event (Terra's reminders tick
the habit from one). `World::shortcuts` binds **global keys** through the
desktop's portal and sends a `shortcut` event on each press; the desktop
may ask to confirm the keys the first time. Neptune's MPRIS (media keys,
the desktop's player widget) lives in its audio crate.

## The palette and the hero

Ctrl+K opens the **command palette** (`Palette`): the sections, the window's
`commands`, and what its `find` turns up as you type (Saturn searches
titles, Neptune the library, Mercury the dictionary). `Shell.go(path,
params, { item, url })` flies a picture from where it was clicked to the
new page's `hero` (a poster to the title page, a cover to the album).
`Tone` reads a picture's colour for tinting; `Spark` is a burst of
particles for a moment that earns one.

## Feel

The first screen's `Sheet` goes in the page's `header`: it stays while the
page scrolls under it and shrinks to a bar, the world sinking into the
corner and the name taking its place. Cards and `Settle`d rows arrive when
they scroll into view, not before. Pages have real inertia: a drag past the
end gives and springs back, the wheel bounces at the ends. A page opened
from another slides in from the right and back out; a section settles.
The sidebar's field filters the page in place when the page says
`filters: true` (it reads `filter`), and searches the app otherwise; `/`
focuses it. `Editable` turns words into a field on click (a `PageHead`
with `editable: true` renames); `Check` shows the click at once and takes
it back with a shake on `fail()`; a `Card` with a `menu` opens it on
right-click. `Skeleton` draws a page's shape while its data is on the way.
`Sounds` (off until turned on in `DeviceCard`, which also picks the
world's accent from its photograph) gives a tick, a done and an off.
Fractional scaling works as Qt does it: `QT_SCALE_FACTOR=1.5` to check.

## Motion

Every screen settles into the pane and settles again when the Shell comes
back to it; the page it replaces fades under it. Lists arrive with the
stagger, bars grow from their baseline, figures count up, the first screen's
band drifts with the scroll and breathes while it waits, the main action's
glow breathes too, a card's ticks answer the pointer, and menus, notices,
hints and the dialog sit on real glass, the page blurred behind them and
bent a little at the panel's edge. The worlds are alive: clouds drift over
Terra, Neptune and Titan, Sol's corona flickers, every limb glow breathes
(`live` in `Worlds`, `time` in the body shader). Switches and the sidebar's
light move on springs. The durations in `Theme` (`fade`, `lock`, `settle`,
`rise`, `drift`) are the only ones; nothing moves without saying what
changed, and nothing loops while the window is hidden or behind another
(`Theme.alive`). `SOL_FPS=1` writes the frames painted a second to the
journal: 170 on a 170 Hz screen.

Look at the picture before calling a screen done, and read the journal: a
binding that fails leaves a card empty without a word on the terminal.
