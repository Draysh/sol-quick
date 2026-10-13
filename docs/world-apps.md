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
Cargo.toml        the app and the workspace: the version ([workspace.package];
                  tag releases v<version>), sol-quick on a tag
sol-world.json    the manifest: id, name, tagline, role, repo, parent (a moon),
                  collections, emits, actions, settings, connections
build.rs          the app's QML module Sol.<World>: every qml/*.qml
src/main.rs       the World handed to sol_quick::run, and the engine's static
crates/<world>-core/
  Cargo.toml      the logic: orbit and sol-quick-core (named sol-quick) on tags, no Qt
  src/lib.rs      the world's logic and `commands()`, which gathers every
                  module's (src/*.rs for the rest; src/desktop.rs what the
                  desktop sees of it, src/sample.rs the preview's data)
qml/Main.qml      the AppWindow: sections, pages, the window's own wiring
qml/<World>.qml   the world's singleton: state and words the screens share
qml/*Page.qml     one Screen per page; other files are the pieces they share
sample.json       preview data, where a world keeps it outside sample.rs
scripts/          icon.sh, install-local.sh, signing-key.sh
update.pub        the key release files are signed with
```

- **`main.rs`** is wiring: `sol_quick::run(World { manifest, update_key,
  version, bin, icons, handler, commands: world::commands(), main, source,
  sample, prepare, tray, shortcuts })`, and the engine's static for a world
  with one (`use <world>_core as world;`). The logic and the commands live
  in the crate `<world>-core`.
- **The logic crate** (`crates/<world>-core`) depends on orbit and the
  kit's half without Qt (`sol-quick = { package = "sol-quick-core", … }`,
  so it says `sol_quick::…` as the app does), never on cxx-qt: its tests
  build and run in seconds, `cargo test -p <world>-core`, even right after
  a kit change. Anything that needs Qt stays in the app. Its `lib.rs`
  holds `MANIFEST` (`sol-world.json`), the collections, the events (each with a
  one-sentence summary), the `Handler` (what it does for each action in
  `sol-world.json`, and `widget.toggle`), the widget for Sol's overview,
  and `commands()`, which calls each module's `commands(&mut c)` and
  registers the desktop's. Its test `the_manifest_is_sound` checks
  `sol-world.json` against the code with `assert_manifest` (Tests, below),
  and `the_screens_commands_are_all_here` keeps the list of command names
  the QML calls.
- **The QML**: `Main.qml` is an `AppWindow` with `world`, `sections`
  (each with an `icon`, an `Icon` name of its own among the world's
  sections), `pages` (path → Component; a path not in the sections is a
  page opened from another, e.g. `/title`; a section may have `children`,
  pages of its own under one row that opens out while one of them is
  open, so the sidebar stays at about nine rows), `aliases` (paths that
  moved, still reachable: `{ "/calendar": "/schedule?tab=calendar" }`),
  `search`, `shortcuts`, and as needed
  `commands`, `find`, `footer`, `busy`, `warn`, `widget`, `widgetName`.
  State the screens share lives in the singleton `qml/<World>.qml`
  (`pragma Singleton`, `import Sol.Design`); every file that uses it
  imports `Sol.<World>`. The first page starts with a `Sheet` in its
  `header` (its title card, and two or three `figures` with their
  Japanese: the numbers that matter most, never a row of facts), other
  pages with a `PageHead` (its `tabs` for views of one page, each in the
  page's path: `/schedule?tab=calendar`; its `feature` for the page's one
  lead object); everything else is `Card`s in a `Grid` (`masonry: true`
  where their heights differ a lot; `span: 2` or `"row"` for a feature
  card). A page with little on it says `sparse` (composed to the still on
  a wide window: its big title and its column one group low on the left), a page with a cover or art beside its content puts it
  in `side`. One `primary` button per screen, and `danger` for what can't
  be taken back. The Settings page is a `SettingsScreen`: the kit brings
  Sol, Export, This device, Updates and each carried moon's part, and the
  world adds its own `SettingsPart`s (see "Moons"). A picture that can't
  be had is the kit's card (give a `Picture` its `name`, or a `seed` when
  the name shows beside it). The look is Yozora
  (`../../docs/yozora.md`), and a world adds only words: a
  section's `jp` (its name in Japanese), a PageHead's, Card's or Sheet's
  `jp`, and a page's `sayJp` and `say` (what its navigator says there:
  the Japanese first, then the English, about 60 characters at most, in
  the character's own voice, never the page's title or its empty state
  again; "" keeps it quiet). A page whose line follows its state keeps
  both in one list, `readonly property var talk: cond ? ["…", "…"] : …`
  with `say: talk[1]; sayJp: talk[0]`.

## Data goes through the Link

The screens never talk to Sol; they call the app's commands
(`Sol.call("name", args)`, a promise), and the commands use
`orbit::link::Link`:

- Documents: `list_prefix(collection, prefix)` and `list_prefix_as::<T>`
  (the documents whose ids start so, by the local copy's index: one
  title's episodes, `<key>_`) and `count(collection, prefix)` (`""` for
  all), for a page that needs one part of a collection that grows;
  `list_as::<T>(collection)` (rows of another shape are
  skipped, and how many is logged when it changes), `list_with_ids`,
  `list_counted` (the rows and that count, for a page that says "2 couldn't
  be read"), `get_as::<T>(collection, id)`, `put_as(collection, id, &value)`
  (keeps an `f32` as written), and the raw `list`, `get`, `put`,
  `overwrite` (last write wins: only for state like where playback stands or
  the last page open, never for what the person made), `delete`.
  `orbit::doc::value_of(&v)` is the f32-safe `to_value`, for event data too.
  A stored shape that has changed, or may, carries `v` (its schema version,
  `#[serde(default = …)]` 1 for rows written before it).
- Events and widgets: `emit` (an event other worlds' connections hear),
  `push_widget`, `remove_widget`.
- Settings: `settings()` reads the world's settings as set in Sol;
  `link.on_settings(|why| async move { … })` calls back first
  (`Configure::Start`) and on every change (`Settings`, `Status(..)`,
  `Lagged`), so an engine set up from the settings follows them. Spawn it
  on the runtime handle `prepare` is given: `tokio.spawn(link.on_settings(…))`.
- Time: the person's zone is `link.time_zone()`, never the machine's.
  "Today" for a world with a `day_starts` setting (Terra, Luna, Mercury,
  the template) is `orbit::clock::Clock::of(&link).await.today()` (04:00
  until the person sets it, `DEFAULT_DAY_STARTS`, which the setting's
  default in the manifest must say too), or `Clock::with` when the
  settings are already read; `day_of`, `at`, `start_of`, `parse_time`,
  `time_setting` are there too. A world without one (Saturn, Titan,
  Neptune, Triton) uses `Clock::calendar`: midnight in the person's zone.
- The screens learn of changes with a `Watch` on the collections a page
  reads (`Watch { collections: ["habits", "checks"]; onChanged:
  page.load() }`, documents here or on another device; `settings: true`
  for the world's settings too), never by reloading on every change; a world's own news to its
  screens goes out with `sol_quick::emit(name, &data)` and arrives as
  `Sol.onEvent(name, data)`.
- Errors: the world's code returns `anyhow::Result` (never `Result<_,
  String>`); the kit turns a command's error into the screens' one
  sentence with its causes (`{:#}`, `sol_quick::say`), so a command has no
  `map_err` of its own.

## A command

A module registers its commands next to the functions they call: the
arguments are the struct the closure takes (`()` for none, as the screen
may send `{}`), the reply anything serialisable.

```rust
// crates/terra-core/src/habits.rs
#[derive(Deserialize)]
struct Tick {
    id: String,
    done: bool,
}

pub fn commands(c: &mut sol_quick::Commands) {
    c.add("list_habits", |link, ()| async move { habits(&link).await })
        .add("tick_habit", |link, a: Tick| async move { set_done(&link, &a.id, a.done).await });
}

// crates/terra-core/src/lib.rs
pub fn commands() -> sol_quick::Commands {
    let mut c = sol_quick::Commands::default();
    habits::commands(&mut c);
    diary::commands(&mut c);
    desktop::desktop().register(&mut c);
    c
}
```

The name is what the QML calls (`Sol.call("tick_habit", { id, done })`),
so it changes only together with every screen that calls it. A world
built around an engine hands each command the engine instead of the link
(`Commands::engine(&ENGINE)`, then `c.into()` for `World::commands`; the
engine keeps the link), and one with state beside the link takes both
(`Commands::over(move |link| (link, titan.clone()))`, Titan).

## The kit's helpers: use these, don't write your own

- **A big collection read by many commands**: `sol_quick::kept::kept::<T>(&link,
  "cards")` reads it once and keeps it until it changes (a write here or a
  change from Sol), so a page's five commands don't read every card five
  times. Prefer it to `list_as` for any collection a world reads on most
  pages; count with `link.count` instead of reading bodies.

**Rust** (`sol_quick::…`):

- `data_dir(world)` (the local copy, the window's state, `seen/`) and
  `cache_dir(world)` (what can be fetched again: pictures, covers, spoken
  words; `~/.cache/digital.sachi.sol.<world>`, the preview's own folder
  under `SOL_PREVIEW`).
- `Shared<T>` and `handler(…)` for a world with an engine built in
  `prepare`:

  ```rust
  static ENGINE: sol_quick::Shared<Engine> = sol_quick::Shared::new();
  commands: world::commands(&ENGINE),   // Commands::engine(&ENGINE): each is handed ENGINE.get()
  handler: sol_quick::handler(|| world::World(ENGINE.get())),
  prepare: Some(Box::new(|link, tokio| { ENGINE.set(Engine::new(link.clone())); /* tokio.spawn(…) */ })),
  ```

- `say`, `emit`, `device_name`, `runtime()` (the link, the runtime handle,
  `preview`), `quit`.

**QML** (`Sol`, `Format`, `Theme`, components):

- `Sol.fail(title, why)`: a failure as a notice from this world.
- `Sol.fileUrl(path)`: a file on disk as an address for an Image or a
  sound, its name encoded (a `#` or `%` in it still reaches the file).
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
- A thing's menu (a title, a deck, a station, a habit): one function of
  the thing returning ContextMenu's entries, given to its `Card { menu }`
  (right-click and a ⋯ in its head), or to a row's `MenuArea` and
  `MoreButton`, or opened from a MouseArea of your own with
  `win.menu.openAt(item, mouse, entries)`; an entry with `items` nests
  ("Rate…" with its numbers inside). Neptune's `trackMenu`/`albumMenu`
  built from `queueing()` and `addTo()` are the model.
- Tabs: `PageHead { tabs: [{ id, label }]; tab: page.params.tab || "" }`
  and read `head.current`; the Shell keeps the tab in the page's path, so
  Back and links reach it (list them in the section's `tabs` too for the
  palette to reach them from anywhere). Two pages merged under one
  section keep a file each: the second tab is a page of its own
  (`pages: { "/schedule": calendar, "/schedule?tab=timeline": timeline }`),
  both with the same PageHead `tabs` (the second's `tab: page.params.tab
  || "timeline"`), and the old paths stay as `aliases` (Saturn's
  Discover, Schedule and Activity).
- `Strip` for anything that scrolls sideways; `Settle` for anything that
  arrives in a list (`pop: true` for a tile in a grid, `pushed:
  mouse.pressed` for a row that plays or opens); `Lean` in a tile that is
  clicked (it leans to the pointer and gives under a press); for a world's
  main act, the kit's small moments: `Check { sparks: true }`,
  `Card.lockOn()` (something gone live), `Button.pulse()` (a press from a
  key), `Spark`, and `Sol.cheer()` with `Sounds.voice()`; `LongGrid` / `LongList` with a `Sift` for a list that
  grows with the library (only what is in sight is made; a Repeater makes
  everything, so keep it for short lists); `Skeleton` for a page's shape while it loads;
  `Chart`, `DataRows`, `Display` for figures.

## The desktop around the app

The Sol desktop (Noctalia's bar and launcher, Umbriel's keys, fastfetch;
`../../deploy/desktop` in the workspace) shows what the running worlds are
doing without a window, and other worlds' apps on this computer ask each
other things. A world says all of it once, in its core's `desktop.rs`: a
`sol_quick::desktop::Desktop`, registered in `world::commands()` with
`desktop::desktop().register(&mut c)`. The kit adds the four
commands its single-instance door reaches (the only ones that are),
routes each action and question by its id, and answers quick capture:

```rust
pub fn desktop() -> Desktop {
    Desktop::new("Terra")
        .status(|link| async move { status(&link).await })   // the bar
        .action("tick", |link, habit| async move { tick(&link, habit.as_deref()).await })
        .find(|link, query| async move { find(&link, query).await })
        .verb(&["slept", "sleep"], slept)                       // quick capture
        .verb(&[], tick_by_name)                                // every line
        // .asked(|link, q: Furigana| …) and .told(|link, d: Duck| …): another world's
}
```

A world built around an engine takes the static it keeps it in
(`desktop(&ENGINE)`, `&'static sol_quick::Shared<Engine>`) and calls
`engine.get()` inside each closure; a test leaks one
(`Box::leak(Box::default())`) and sets its engine.

- **`status`** (no arguments): a small object (now playing, habits left,
  the next episode, cards due) with an `open` page for a click. The kit
  writes it, with `world`, `name`, `pid` and `at` beside it, to
  `$XDG_RUNTIME_DIR/sol/<world>.json` (`preview-<world>.json` in a
  preview; in memory, removed when the app leaves) whenever it changes: it
  asks at start, on every change to the world's documents or settings,
  once a minute, and when the world calls `sol_quick::status::refresh()`
  (news the documents don't carry). `sol-<world> --status` prints it. Keep
  it small and cheap: nothing fetched. The desktop's plugin
  (`deploy/desktop/noctalia-plugin/worlds`) and `fastfetch/sol-worlds.sh`
  read its fields: add freely, change one only together with them.
- **`action(id, …)`** (the `do` command, `sol_quick::door::Do { id, arg }`
  → one sentence): from a key or the bar, `sol-<world> --do tick walk`. An
  id nobody registered is answered "Terra can tick, not “dance”".
  `desktop::matching::pick_by_name_or_next_open` is "the one named (by id
  or name), else the next still open" (Terra's habits, Luna's rituals).
- **`find`** (`door::Query { query }` → `Vec<Found { title, subtitle,
  open, kind }>`): what the launcher finds here, local only, `sol-<world>
  --find <words>` (JSON).
- **`verb(words, read)`**: quick capture (below).
- **`asked` / `told`**: a question from another world's app on this
  computer, typed in `sol_quick::questions` (below); an id nobody
  registered is answered "Mercury can't answer “x”".

`--do` and `--find` ask the running copy through its door and print
"<World> isn't running." (exit 3, or `[]` for `--find`) when none runs.

### Asking another world

Another world's app is asked while both run, never started:
`sol_quick::questions::ask(Furigana { lines }).await` for a question with
an answer, `questions::tell(Pause).await` for something to do (both off the
async runtime by themselves; `door::ask` / `door::tell` underneath take an
untyped id and JSON). A preview asks the preview's copy, and
`Unanswered::NotRunning` says to do without. This is for what a running app
knows (a dictionary, what's playing), never for its data, which stays in
its own documents. Each question is a type naming the world that answers
it and its id, so both ends read it alike:

| Question | Asked of | By | Answer |
| --- | --- | --- | --- |
| `Furigana { lines }` (`ask furigana`) | Mercury | Neptune | `Readings { lines: [[Word { parts: [Part { base, rt? }], word?, entry? }]] }`, readings over Japanese lyrics |
| `AddWord { word, entry?, line }` (`do add-word <word or JSON>`) | Mercury | Neptune | a sentence: the word in "From songs" |
| `Say { text }` (`ask say`) | Mercury | Triton | `Spoken { path }`, a WAV in Mercury's voice for the DJ |
| `Level` (`ask level`) | Mercury | Triton | `Known { level, hiragana, of, learned }`, how much Japanese the DJ speaks |
| `Now` (`ask now`) | Neptune | Triton | `Playing { state, id, title, artist, position, duration }`, between tracks |
| `Duck { level, ms }` (`do duck {"level","ms"}`) | Neptune | Triton | a sentence: the music lowered under the DJ's voice |
| `Pause` (`do pause`) | Neptune | Luna | a sentence: the music paused at the end of a wind-down |

The wire is what installed apps of other versions speak, so it changes
only with additions that have defaults. The answering world keeps each
question's fixture, `fixtures/questions/<id>.json` (`{ asked, arg, answer
}`), checked by `testing::assert_asked::<Q>` / `assert_told::<T>`; each
asker keeps a byte-identical copy (`fixtures/questions/<world>-<id>.json`),
checked against the answerer's by `testing::assert_copy` when the sibling
checkout is there, and asks a `FakeDoor` answering it. A new question is a
type in `questions.rs` (with its row here), an `asked`/`told` line in the
answering world, and the two fixtures.

## Quick capture

One line over the desktop, from a key (Umbriel's Mod+Alt+C runs
`deploy/desktop/bin/sol-capture`, which knocks `ask capture null` on the
first running Sol app's door; that app opens `assets/capture/Capture.qml`,
a layer-shell window, namespace `sol-capture`, frosted like the widgets).
As the person types, the kit's `capture` command asks every running
world's `ask` the question `capture`, through its door, 100 ms at most
each (`capture::BUDGET`); the line shows the best offer ("Terra · tick
Walk"), ↑ ↓ choose, Enter asks that world again with `go` and shows the
sentence it answers, Escape closes. It never starts an app; the ones
installed and not running are named under the line.

A world answers with its verbs. A verb is one function: the kit calls it
for a line whose first word is one of its `words` (every line, for `&[]`)
with the line as a `Typed { line, verb, rest }` (`verb` the first word
lowercased, `rest` the others as typed), and it answers None (not its
line) or a `Plan`: what it would do, how sure, and the doing.

```rust
/// "slept 7.5": last night's sleep on this morning's page.
async fn slept(link: Link, typed: Typed) -> anyhow::Result<Option<Plan>> {
    let Some(h) = hours_of(&typed.rest) else { return Ok(None) };
    Ok(Some(Plan::new(format!("slept {h} h last night"), matching::VERB, async move {
        log_sleep(&link, h).await?;
        anyhow::Ok(format!("Slept {h} h last night, on this morning's page."))
    })))
}
```

The kit offers the surest plan of the world's verbs (the first added,
between equals), and runs it only on Enter: do nothing before the `async
move` (an offer is asked for on every key). `Plan::said(does, sure,
sentence)` is a plan with nothing to do ("Walk is done today already").
An offer comes from what is here, nothing fetched. Keep the reading a
pure function with a test; `Desktop::capture(link, line, go)` (or `ask`
with `testing::capture_q`) runs the whole of it in a world's test.
`sol_quick::open(path)` opens a page in the window when doing it needs one
(Mercury's "review"). `_capture=<line>` in a shot path stages it.

### How sure: one scale

The best offer of all the running worlds is the one shown, so every world
says how sure it is on one scale, `sol_quick::desktop::matching`:

| Sure | When |
| --- | --- |
| `EXACT` 1.0 | the line is one of the world's names, as written ("Read" for the habit Read) |
| `VERB` 0.9 | one of its verbs, with all it needs ("bedtime", "rate 8", "watched frieren") |
| `PREFIX` 0.8 | a name starts with what was typed ("walk" for Walk outside) |
| `ALL_WORDS` 0.7 | every word typed is in a name ("drive night" for Night Drive; a word of one or two letters must start one of its words) |
| `SOME_WORD` 0.5 | one word typed is a word of a name ("walk the dog" for Walk) |
| `GUESS` 0.3 | the world's own words, likely not meant ("pause" with nothing playing) |

`matching::score(typed, name)`, `best(typed, items, name_of)` and
`rank(…)` (the surest first, the world's own order between equals) look
a name up; a name after a verb is `matching::after_verb(sure)`, at most
`VERB`. No world makes up a number of its own.

Every world's words, so a new verb doesn't take another's (no first word
is any other world's today):

| World | Words | What it does | Sure |
| --- | --- | --- | --- |
| Terra | a habit's name, its start or its words, with or without `tick`, `did`, `done` | ticks it today | the name's: 1, 0.8, 0.7, 0.5 |
| Terra | `slept 7.5`, `sleep 7,25h` | last night's sleep on this morning's page | 0.9 |
| Luna | `bedtime`, `bed [now / 23:10]`, `sleeping` | tonight's bedtime | 0.9 |
| Luna | `wind down [30 / until 23:00]`, `winddown` | a wind-down | 0.9 |
| Luna | `evening`, `begin` / `start` (with "evening" or alone) | begins the evening | 0.9 |
| Saturn | `watched`, `saw`, `seen` [title] [episode, `s2e3`, `2x3`] | ticks the next or the named episode | 0.9 bare; a title: its name's, at most 0.9 |
| Saturn | `rate 8`, `rate 8/10` | rates the episode watched last | 0.9 |
| Neptune | `pause`, `stop`; `resume`, `play`, `unpause`; `next`, `skip`; `previous`, `back` (alone) | the player's keys | 0.9 (0.3 with nothing playing) |
| Neptune | `play` / `put` <album, artist or song> | plays it from the library | the name's, at most 0.9 (artist, album, song between equals; 0.5 a song found by something else) |
| Triton | `radio`, `station` [surprise, anime, a decade, a genre, an artist, an album] | starts a station | 0.9; a name: its own, at most 0.9 |
| Mercury | `review`, `study`, `reviews` [deck] | opens a review | 0.9; a deck: its name's, at most 0.9 |
| Mercury | `add`, `learn` <word> | adds it to "Added from anywhere" | 0.9 (0.3 not in the dictionary) |
| Template | `log`, `note` <text> | logs the line | 0.9 |

Titan answers none. Terra's habit names are the person's own, so any
line may reach it: a habit named exactly as another world's verb
("Review") is sure 1 and comes first; part of a name comes after a
verb's 0.9.

## Moons

A moon (Luna, Titan, Triton) names its planet in `sol-world.json`
(`parent`) and has no app of its own: its planet's app carries it
(`"app": "<planet>"` in the moon's manifest). It stays a world of its own
in Sol (its id, collections, events, settings, connections, export), and
in the planet's process it has its own link, local copy
(`~/.local/share/digital.sachi.sol.<moon>`), door (`sol-<moon>`) and
status file, so the desktop's `sol-<moon> --do/--find/--status` and other
worlds' questions reach it as before.

- **The moon's repository** has two crates: `crates/<moon>-core` (its
  logic, no Qt, with `pub fn moon() -> sol_quick::Moon`: manifest,
  version, icons, handler, commands, sample, prepare, `module:
  "Sol/<Moon>"`) and `crates/<moon>-screens` (the QML module `Sol.<Moon>`
  from the repository's `qml/`, through a `qml` link, and `SOURCE` for live
  QML). No binary.
- **Its screens**: `<Moon>Moon.qml` is a `Moon { world; sections; pages;
  commands; moments; overlays }`, paths relative to the moon (`/` its
  first page). The singleton keeps `readonly property var sol:
  Sol.of("<moon>")` and every page calls through it (`Luna.sol.call`,
  `.undoable`, `.fill`, `.fail`, `Connections { target: Luna.sol }`);
  `Watch { world: "<moon>"; … }`; its settings part (below) has `SolCard`,
  `SettingsCard` and `ExportCard` with `world: "<moon>"` (the app's
  updates and autostart are the planet's); its device settings are a
  `WorldSettings { world: "<moon>" }` (the file its own app kept).
- **One Sky and one Settings per app**: the moon has no Sky or Settings
  row of its own. Its `Moon { settings: Component { <Moon>Settings { } }
  }` (a `Grid { masonry: true }` of its cards, Titan's `TitanSettings`)
  is a part of the planet's `SettingsScreen`, under the moon's name;
  without a `/sky` page its sky is a tab of the
  planet's `SkyPage`. `/<moon>/settings` and `/<moon>/sky` still open
  them there (`/settings?part=<moon>`, `/sky?tab=<moon>`), and the moon's
  own paths that moved are its `aliases` (relative to the moon: Titan's
  `{ "/galaxy": "/taste?tab=galaxy" }`).
- **The planet** depends on both crates (`worlds.sh` points them at the
  moon's checkout or its release tag), starts them in `main.rs`
  (`init_crate!(<moon>_screens)`, `init_qml_module!("Sol.<Moon>")`,
  `sol_quick::run_with(World { … }, vec![Moon { source:
  <moon>_screens::SOURCE, ..<moon>_core::moon() }])`) and lists the moon
  in its window: `import Sol.<Moon> as <Moon>Screens` (a name: both
  modules have a `SettingsPage`) and `moons: [<Moon>Screens.<Moon>Moon { }]`.
  The moon's sections are a group of the sidebar under its name, its pages
  under `/<moon>` in its colour, each page's `Screen.world` the moon.
- **Pairing**: once the planet is paired, the moon pairs through it
  (`Link::pair_through`, Sol's `pair/carried`): no second code.
- **Events and moments**: the moon's Rust tells its pages with
  `sol_quick::emit_in(link.world(), …)` (they hear it on `<Moon>.sol`); a
  moment it plays passes `world` (`moment.play({ world: "luna", … })`).
- **Its own app goes**: the planet's `--install`, and the first start of
  an installed planet, take the standalone moon app away (asking a running
  one to quit), leave `~/.local/bin/sol-<moon>` as a link to the planet,
  and move the moon's start at login to the planet (windowless). Its data,
  token and settings file stay.
- **Pictures**: `/shots <moon>` shoots the planet's app at `/<moon>/…`;
  the moon's preview data is its own (`/tmp/sol-preview-<moon>`).

In the sidebar, the doors (`Sol.doors`) lead to Sol and to the kin
installed here and not carried; a Sheet's moon links (`Sol.moons`) open a
carried moon's (or the planet's) pages in the same window.

## Moments

`win.moment.play({ occasion, scene, facts, chime, length })` (the kit's
`Moment`, one per window) plays a scene over the whole window: it fades
in, plays a few seconds (5.2 unless `length` says, 2.6 and still with less
motion) and goes on any key or click, only while the window is in front.
An occasion plays once for the person, on any device: the kit's `moment`
command records it in the world's `moments` collection (documents `{
occasion, at, device }`, the id `moments::occasion_id(occasion)`), so a
world that plays one lists `{ "id": "moments", "label": "Moments shown" }`
in `sol-world.json` and the hub's catalog copy (`assert_manifest` checks
it). Without an occasion it plays every time. Name occasions so one that
may come again is another (`saturn.finished.<key>.<run>`,
`terra.all-done.<day>`). A scene is a Component with `property var
moment` (its `progress`, `facts`, `calm`); `MomentCaption` is its words.
A world names the ones a picture can stage in `AppWindow { moments: ({
sunrise: () => ({ scene: sunrise, facts: … }) }) }` (an object, or a
function of an argument giving one or a promise of one), and
`_moment=<name>` (or `<name>:<arg>`) in a shot path plays it, without its
occasion: Terra's `sunrise`, Saturn's `finished:<key>`, Mercury's
`perfect` and `milestone`, the template's `first`. The template's
`FirstLine.qml` is the smallest example. A moment is a
film's scene over the page's still: give its MomentCaption `jp` (the title
in Japanese), `subtitleJp` and `subtitle` (a line said at the foot, by
the world's navigator, who stands large beside it), and
the spec a `hud` ("Review · 復習"); Mercury's `PerfectScene` does.

## The Sky

Every world has a Sky page (`/sky`, the kit's `SkyPage`): the person's
milestones as stars that join into named constellations ("100 Nights",
"First 500 Words", "The Ghibli Run", "Every Opening of Bleach"), lit as
they are reached. The world says what its constellations are, from its own
data; the kit lights, keeps, lays out and draws them, and plays a star's
moment.

```rust
// crates/<world>-core/src/sky.rs
use sol_quick::sky::{self, Constellation};

/// The world's constellations as its data stands now.
pub async fn constellations(link: &Link) -> anyhow::Result<Vec<Constellation>> {
    let nights = count_nights(link).await?;
    Ok(vec![
        Constellation::new("nights", "100 Nights", "Nights logged, one at a time.")
            .steps(nights, &[1, 10, 30, 50, 100], |k| (format!("{k} nights"), format!("{k} nights logged."))),
        Constellation::new("ghibli", "The Ghibli Run", "Every Studio Ghibli film.")
            .star("totoro", "My Neighbor Totoro", "Watched to the end.", watched("totoro")),
    ])
}

pub fn commands(c: &mut sol_quick::Commands) {
    c.add("sky", |link, ()| async move { sky::show(&link, &constellations(&link).await?).await });
}
// After a write that may reach one (a night logged, a film finished):
// sky::record(&link, &constellations(&link).await?, true).await?;
```

- **Ids are for good**: a lit star is a document in the world's `sky`
  collection under its constellation's id and its own, so neither may
  change once released. A star the world stops defining stays lit, in its
  constellation (or one under its old title).
- **Constellations from the person's own things** are made from the data
  when there is some (one per franchise or show they are into: "Every
  Opening of Bleach"), with a few made to be reached over months. Three to
  six constellations, each three to eight stars, is a sky that reads well;
  a star's title names the milestone ("100 nights"), its story says it in
  a sentence.
- **Lighting**: `sky::record(&link, &constellations, true)` after the writes
  that can reach a milestone (it reads `sky` only when something is
  reached), and `sky::show` in the `sky` command, so nothing is missed.
  The first filling of a sky is quiet; after that the newest star lit
  plays the kit's moment (`sky.lit` → `StarScene`), one at a time.
  Recording reads the data again, so keep `constellations` to counts the
  world already has at hand; never call it on a timer.
- **The page**: `pages: { "/sky": skyPage }` with `Component { id:
  skyPage; SkyPage { } }` and a section `{ path: "/sky", label: "Sky",
  icon: "sparkles", hint: "Your milestones, as stars" }` (last before
  Settings). A carried moon leaves its Sky page out: its sky is then a
  tab of its planet's (`/sky?tab=<moon>`, "Moons"), from its own `sky` command. The manifest lists `{ "id": "sky", "label": "Stars in your
  sky" }` (and the hub's catalog copy); `assert_manifest` checks it.
- **A map of its own** (Mercury's path, Titan's galaxy) is a `StarField`
  with the world's stars, lines and names as its children (`StarLight`,
  `StarArc`, `StarLine`, placed with `sx`/`sy`); names are placed on the
  field's `place()`, never in a binding on the view.
- **Comets** come to every world's Sheet on its own few days a year; a
  click catches one as a star in "Comets". **The real sky**: Luna's Sheet
  says so on a full moon and the Perseids, Saturn's at its opposition, and
  each lights a star in "Under the real sky". Both are the kit's, with
  nothing for a world to write.
- **Preview**: the sample data reaches a few stars, so a preview's Sky has
  some lit. Pictures: `/sky`, `/sky?star=<constellation>/<star>` (one
  chosen), `_moment=star`, and on the first page `_comet=1` and
  `_sky=full-moon|perseids|opposition`.

## Undo

Every tick, rating, grade, status and delete can be taken back for a few
seconds. The Rust side says what a write touches, so the screens never
spell a document's id:

```rust
c.undoable(
    "archive_habit",
    |_, a: Id| async move { Ok(vec![sol_quick::doc(HABITS, a.id)]) },  // what it changes
    |link, a: Id| async move { archive(&link, &a.id).await },
)
// A write that makes documents: Undo deletes what `made` names from the reply.
.creates("create_habit", |h: &Habit| vec![doc(HABITS, &h.id)], |link, a: Name| async move { … })
```

`touches` is handed what the command is (the link or the engine) and its
arguments, so it may look things up first (Mercury's deck lists its
cards). The screens call `Sol.undoable("archive_habit", { id }, { title,
body, undone })`: the kit reads those documents, runs the write, keeps
them as they were under a token (in memory, the last 64), and its notice
says what was done, with Undo for its twelve seconds, which sends the
token back (`restore { undo }`, the world's own collections only).
Called with `Sol.call` the same command is a plain write.

A write whose way back reaches outside Sol passes `undo: (result, token) =>
promise` instead: a Navidrome star or rename (`token` null: nothing kept),
Luna's wind-down (`cancel_wind`), and Saturn's `put_back`, the pattern for
side effects elsewhere: its writes keep the title's document, and
`put_back { key, undo: token, tick }` takes it (`sol_quick::undo::take`)
and puts the title back through the engine, which tells AniList too. An
event already sent to Sol stays sent.

## Keys first

The window's `commands` and each page's `Screen.actions` are the
palette's rows ("Rate 8", "Next episode watched", "Bury this card", with
`keys` where a key does it too; `win.allCommands` is both, with the
page's other tabs), and `?` lists them with the Shell's keys and the
app's `shortcuts`. Ten rows of a kind are one row with `items` ("Rate…"
with its numbers inside): it opens its own list, and typing "rate 8"
still finds the one inside.

## The first run, empty pages, the voice

- **The tour**: `AppWindow { tour: [three cards] }`, each `{ title, body,
  keys?, icon?, go?, start? }`: what the world does, its best key (`keys:
  "Space V"`, drawn as keycaps), where to start (`go: "/kana", start:
  "Open Kana"`). The kit shows it once on a device, the first time the
  window is in front (`sol.<world>` `toured`; never in a preview, a
  picture or a drive), skippable, and puts it behind `?` and the palette
  ("Take the tour"); `_tour=N` stages card N for a picture.
- **Empty pages**: `Empty { icon; jp; line; hint; action }` wherever a page or
  card has nothing yet: the line in the world's own voice ("Nothing in
  orbit yet.", "Only static, so far."), said by the navigator beside it
  with its Japanese (`jp`) first, the hint saying what fills it, at
  most one action. Inside a card, or for a search with no hits, `compact`
  (the glyph in a diamond, no navigator).
- **Its navigator's cheer**: `Sol.cheer()` beside that same good moment
  (an episode watched, a habit ticked, a card remembered, a song starred,
  a bedtime logged, a station on air): the portrait glows warm and sparks
  once. Never for every click.
- **Its voice**: `Sounds.voice()` for the world's main good moment only (an
  episode watched, a habit done, a right answer, a station on air), never
  for every click; the kit's `tick` stays for the rest. A new world adds
  its sound in the kit (`Sounds.voices`, `scripts/world-sounds.py`).

## Writes, conflicts and what is kept

- `link.put` (and `put_as`) sends the version of Sol's copy the write was
  made on: when another device changed the document first, Sol's copy
  stays and this one is kept aside as a conflict, shown by the kit
  ("Changed on another device too", `KeptAside`), and the person picks.
  Use `link.overwrite` only for state that matters as it is now (where
  playback stands, the page last open), never for what the person made.
- Writes Sol turns down and writes from before an unpairing are kept the
  same way (`link.kept()`, `kept_writes`, `keep_mine`, `drop_kept`,
  `export_kept`); a world needs nothing for any of it, but can show a
  conflict on its own screens from `Sol.kept` / the `kept` command.
- A world's own SQLite files (caches) open with `orbit::db::open_with_backup`
  when they hold what can't be made again; a cache that won't open is set
  aside and made again (Titan's vectors), never an `expect`.

## Export and import

Every world exports and imports the same way, with nothing of its own to
write: the kit's shared commands `export_world` and `import_world` and the
`ExportCard` on the Settings page. The file is the world's own collections
(the ones `sol-world.json` lists, so a collection the manifest leaves out
is neither exported nor imported):

```json
{ "world": "terra", "version": 1, "exported_at": "2026-10-10T20:14:00Z",
  "collections": { "habits": [{ "id": "walk", "data": { "name": "Walk" } }] } }
```

It goes to `~/Downloads/sol-<world>-<stamp>.json`. An import reads the
file first and the card says what it adds and replaces before anything is
written; then every document goes in through `link.put` (so it syncs, and
a document another device changed meanwhile is kept aside as a conflict),
merged by id: missing ones are added, different ones replaced, nothing is
deleted. A file from another world or a newer `version` is refused. A
world may offer more beside it inside the card (Terra's diary as Markdown).

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
  (one file, `sol-<world>`, the binary linked against the system's Qt), with
  `<file>.sig` beside it, `sol-world.json` and `SHA256SUMS`; Sol offers an
  update only for that name shape with a signature
  (`../../kit/orbit/docs/protocol.md`, "Versions and updates"). Releases are
  made on the person's computer, never in CI (a world's
  `.github/workflows/ci.yml` only checks): `../../hub/scripts/build-linux.sh
  <world>` builds it into `out/` (refusing `use-local`, a dirty tree or an
  unpushed tag; `--allow-local` for a build to install here only); signing
  and uploading are the person's (`hub/CLAUDE.md`).
- Installing and updating are orbit's (`install`, `updates`) and the
  `AppUpdates` card; `--install`, `--uninstall`, `--version` (which also
  says the Qt it was built with: an update is started with it before it
  goes in), `--background` (a moon its planet started), `--login` (started
  with the computer: the tray, no window) and `--open /page?key=v` are the
  app's flags. `update.pub` may hold several keys, one per line.

## Live QML: screens without a build

With `SOL_QML_LIVE=1` (which `hidden.sh` sets; `src/live.rs`, `cpp/live.h`)
a preview reads the kit's QML from the kit's checkout and the world's from
`World::source` (`env!("CARGO_MANIFEST_DIR")` in `main.rs`) instead of the
compiled modules, so an edited `.qml` shows the next time the built binary
runs (`~/Projects/sol/target/debug/<bin>`, not `cargo run`, which builds).
A new `.qml` file is seen only by files in its own folder until a build
adds it to the module (another module's `import` and a new singleton need
that build); Rust, shaders and `sol-world.json` need a build too.
`SOL_QML_LIVE=0` shows the compiled QML, and `cargo build` stays the check
that every `.qml` compiles. How to run and shoot a preview is in
`../../docs/agents.md`; every staging key is in the kit's README
("Environment").

## Preview data, logs

- `SOL_PREVIEW=1`: the app with sample data on a throwaway copy
  (`/tmp/sol-preview-<world>`, filled the first time by `World::sample`;
  delete the folder for fresh data, or `touch sampled` in an empty one for
  an empty app). Keep the sample current when a command changes, and give
  it enough to fill every page. A world whose data lives in a service has a
  stand-in where it can: Neptune and Triton play the kit's Navidrome
  (`sol_quick::navidrome`, the `fake-navidrome` feature).
- The app's own log (Rust's `tracing`, panics included) is
  `~/.local/state/digital.sachi.sol.<world>/<world>.log`, or `<world>.log`
  in the preview folder; QML errors go to the journal.

## Tests

Every test is in the logic crate: `cargo test -p <world>-core` while
working (filtered: `cargo test -p terra-core habits::`), and `cargo test`
(every member) at the end. The app binary has none (`test = false`), so
no test builds Qt. A fixture's path is from the file
(`include_str!("../../../fixtures/x.json")` in `src/`), or from
`env!("CARGO_MANIFEST_DIR")` plus `/../..` for the world's folder.

`sol_quick::testing` (always there, no feature: the kit builds once for
the app and its tests):

- `offline_link(world)`: a `Link` with a local copy in a fresh folder and
  no Sol (keep the folder it returns as long as the link); `open(world,
  dir)` opens one again, as a restart.
- `assert_manifest(MANIFEST, Expect { parent, actions, emits, settings,
  collections })`: the manifest parses and has no `problems()`, lists what
  the code uses, defaults `day_starts` to orbit's 04:00, lists `moments`
  when a screen plays one, and matches `../../hub/catalog/<id>.json` when
  that exists. It returns the manifest for a world's own checks.
- `undoably(&commands, &link, name, args)`: a write run as `Sol.undoable`
  runs it (its reply and Undo's token); `take_back(&link, token)`: the
  notice's Undo.
- `capture_q(line, go)`: quick capture's question, for a world's `ask`
  (`desktop().ask(link, capture_q("walk", false))`).
- `assert_asked::<Q>(fixture)`, `assert_told::<T>(fixture)`: a question's
  fixture reads as the kit's types and is written back the same;
  `assert_copy(ours, "../<world>/fixtures/questions/<id>.json")`: an
  asker's copy is the answerer's own.
- `FakeDoor::open(world, |command, args| …)`: another world's running app,
  answering `ask`, `do` and `find` through its door, and `asked()`. Outside
  `sol_quick::run` every door is the process's own (`sol-test-<pid>-…`),
  so a test never reaches an app running on the computer.
- orbit's stand-ins: `FakeHttp` (a canned HTTP server on 127.0.0.1:
  `routes([("GET /api/tags", Reply::ok(…))])` or `start(|request, seen| …)`,
  every `Request` kept), `StandInSol` (no settings, long polls held, writes
  to a function; `paired(world, person)` for a link paired with it).

## Checks

- `cargo build` (it compiles the QML: a bad `.qml` fails here), then
  `cargo fmt --all && cargo clippy --workspace --all-targets -- -D warnings
  && cargo test` (every member's tests).
- Shots of every page in `Main.qml`'s `pages` that the change touches, one
  detail page, and the journal, before and after: one
  `../scripts/shots.sh <world> <folder> <name>=<path>…` call each
  (`../../docs/agents.md`). A world's own staging key with a timer before
  it stages (Neptune's `_vinyl`) counts the wait with `Settling { when:
  timer.running }`, so the picture waits for it (the ready rule: the kit's
  README, "Environment").
- A change to the kit is checked in the kit's gallery, not by sweeping the
  worlds; a world is looked at only when its own screens use what changed.
