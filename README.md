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

Needs Qt 6.12 or later: `qt6-base`, `qt6-declarative`, `qt6-shadertools`
and `qt6-multimedia` (the kit's own sounds use it, so every world does).

## What is in it

- **`src/app.rs`**: `run`, the `World`, the shared commands (connect,
  forget, settings, updates, install, doors, moons, notify), preview mode
  (`SOL_PREVIEW=1` runs against a throwaway copy with sample data) and the
  review hooks: `SOL_SHOT=<png> SOL_SHOT_AFTER=<ms> SOL_SHOT_PATH=<path>`
  for a screenshot, `SOL_FPS=1` for the frames really painted each second
  in the journal (0 while nothing moves), and
  `SOL_DRIVE=<file.qml>` for a script that drives the window end to end, and
  `SOL_LIGHT=night|day` to see one light whatever the device's setting.
- **`src/commands.rs`**: typed async commands the screens call through
  `Sol.call(name, args)`, which returns a promise.
- **`src/bridge.rs`**: the `SolBackend` singleton the QML side talks to.
- **`qml/`**: the `Sol.Design` module. `Theme` (every token), `AppWindow`
  (the window: Connect until paired, then the `Shell`), `Screen`,
  `PageHead`, `Sheet` and `Body` (the world's photo, lit by a shader),
  `Card`, `Grid`, `Button`, `Field`, `Select`, `Toggle`, `Check`,
  `TextArea`, `Slider`, `DataRows`, `Progress`, `Display`,
  `Chip`, `Callout`, `Hint`, `Notices`, `ContextMenu`, `CommandPalette`, `Key` (a key for one page), `Ask`,
  `Ticks` (the keyboard-focus mark every control shows), `Glass` (real
  blur of the pages behind a menu, a notice, a hint or a dialog), `Settle`
  (the stagger every list arrives with), `Poster`, `WorldGlyph`, `Icon`,
  `SolCard`, `AppUpdates`, `SettingsCard`, `WithPlanet`.
- **`assets/`**: the fonts (Outfit, Shippori Mincho) and every world's
  photo; **`shaders/`**: the body's lighting and the glass, compiled with
  `qsb` (after changing one, from `shaders/`):

  ```sh
  for f in body glass; do /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o $f.frag.qsb $f.frag; done
  ```

## Writing a screen

A page is a `Screen` (a `PageHead` in `header`, cards below), the first one
a `Sheet`. State the screens share goes in the world's own singleton
(`qml/<Name>.qml`, `pragma Singleton`), which every file imports with
`import Sol.<Name>`. Lists are `Repeater`s whose delegates are `Settle`d.
What the design kit's `DESIGN.md` says about words, spacing and motion holds
here unchanged; [DESIGN.md](../design/DESIGN.md) has the QML notes.

Light and depth differ from the web's pure black, for long sessions in an
app: the window is a night sky in three depths, and colour still comes only
from the worlds.

| Token | What it is |
| --- | --- |
| `Theme.deep` | The chrome: the sidebar, a `Sheet`'s band and strip, a `PageHead` |
| `Theme.space` | The pane, where the work is: `night` (`#0c0e13`) tinted 5 % by the world's own colour, so each app has its own sky |
| `Theme.raised` / `raisedTop` | A panel off the pane: every `Card` is one, lit a little from above, with `Theme.radius` corners and a hairline |
| `Theme.textWorld` | A panel's title, in the world's light, over a hairline that splits head from body |

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
and Qt 6 has no `Glow` (a `MultiEffect` shadow with no offset is one).

## Checking a screen

```sh
SOL_PREVIEW=1 SOL_SHOT=/tmp/today.png SOL_SHOT_AFTER=2500 SOL_SHOT_PATH=/ cargo run
journalctl --user -S -1min | grep '<world>\['     # QML runtime errors land here, not on stderr
```

`SOL_SHOT_PATH` takes a page's params as a query (`/title?key=x`), and
`_notice=1` or `_ask=1` put a notice or the dialog in the picture.

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

## The palette and the hero

Ctrl+K opens the **command palette** (`CommandPalette`): the sections, the window's
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
focuses it (on the rail it waits behind a button and floats over the pane).
The arrows, Page Up / Down, Home and End scroll the page. Every control
that takes the keys shows it with `Ticks`; a `PageHead` too narrow for its
actions puts them on lines of their own under the title. `Editable` turns
words into a field on click, or Enter (a `PageHead` with `editable: true`
renames); `Check` shows the click at once and takes
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
