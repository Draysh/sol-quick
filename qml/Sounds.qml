pragma Singleton
import QtQuick
import QtCore
import QtMultimedia

/*
    Tiny sounds, a few milliseconds each, for a press (a button, a tab, a
    switch, a box ticked), a thing done (a write that went through), and a
    thing taken back; a soft chime, two seconds; the big acts' stings, in
    each flavour's own sound (made by `scripts/world-sounds.py`): a page
    turning, the opening, a moment, a light coming on; the palette or a sheet opening and
    closing, the keys moving on (the softest click) and something gone
    wrong; and the world's own voice (Saturn's soft ring, Neptune's water drop, Mercury's
    bell, Terra's wood tick, Luna's chime, Titan's whoosh, Triton's static
    blip, made by `scripts/world-sounds.py`) for its main good moment only:
    an episode watched, a right answer, a habit done. On by default and
    low (`level`), so they sit under whatever else is playing; one switch
    in a Settings page's DeviceCard turns them all off on a device, and
    that stays. An off written before sounds were on by default (with no
    `soundsVersion`, as some apps had on 2026-10-11) is forgotten: the app
    writes them on once, outside a preview, and keeps what is chosen from
    then on. Never while the window is asleep, and never two over each
    other: the voice takes the place of a "done" just played, and a burst
    of presses ticks once. Hits only, never anything under the page: a
    burst limiter lets the first of a few sounds close together stand (a
    weightier one still comes through) and no more than six a second.

        Sounds.tick()   Sounds.done()   Sounds.off()   Sounds.chime()   Sounds.voice()
        Sounds.turn()   Sounds.opening()   Sounds.hushOpening()   Sounds.moment()   Sounds.lit()   Sounds.open()   Sounds.close()   Sounds.focus()   Sounds.error()
*/
QtObject {
    id: sounds

    component Prefs: Settings { property bool sounds: true; property int soundsVersion: 0 }
    property Prefs prefs: Prefs { category: "sol.device" }
    /** Which choice of sounds is kept: 1 since the sounds are on by default; an older off is not the person's. */
    readonly property int soundsVersion: 1
    readonly property bool on: prefs.soundsVersion >= soundsVersion ? prefs.sounds : true
    function setOn(v) { prefs.sounds = v; prefs.soundsVersion = soundsVersion; if (v) tick() }
    // The old off is forgotten in the file too, once; a preview shares the installed app's file and leaves it.
    Component.onCompleted: if (prefs.soundsVersion < soundsVersion && !Sol.preview) { prefs.sounds = true; prefs.soundsVersion = soundsVersion }

    /** How loud they all are, 0 to 1: low, under music and speech. Each sound's own volume is its share of it. */
    readonly property real level: 0.5
    property SoundEffect tickSound: SoundEffect { source: "../assets/sounds/tick.wav"; volume: 0.45 * sounds.level }
    // "Done" plays for every write that goes through, so it sits a little under the stings.
    property SoundEffect doneSound: SoundEffect { source: "../assets/sounds/done.wav"; volume: 0.35 * sounds.level }
    property SoundEffect offSound: SoundEffect { source: "../assets/sounds/off.wav"; volume: 0.4 * sounds.level }
    property SoundEffect chimeSound: SoundEffect { source: "../assets/sounds/chime.wav"; volume: 0.28 * sounds.level }

    /** The worlds with a voice of their own, and what it sounds like (DeviceCard says). */
    readonly property var voices: ({ saturn: "a soft ring", neptune: "a water drop", mercury: "a bell", terra: "a wood tick", luna: "a chime", titan: "a whoosh", triton: "a static blip" })
    /** What this world's voice sounds like, or "" for a world without one. */
    /** Whose voice: the world of the page in front (the Shell sets it: a carried moon's own on its pages). */
    property string world: Sol.world
    readonly property string voiceName: voices[world] || ""
    property SoundEffect voiceSound: SoundEffect { source: sounds.voiceName ? "../assets/sounds/" + sounds.world + ".wav" : ""; volume: 0.7 * sounds.level }

    // The flavour's stings (a moon with a flavour of its own has its own; another takes its planet's).
    readonly property string sting: "../assets/sounds/" + Theme.flavour + "-"
    /**
        Each flavour's stings matched to the others of their kind, in dB on
        the kind's volume, so no world's opening, moment, turn or light is
        louder than another's by more than a decibel or so (measured as
        BS.1770 has loudness, the loudest 400 ms, on 2026-10-13): the
        openings and moments at about -32 LUFS as they play, the lights at
        -38 (Mercury's seal, pressed on every right answer, at -42), the
        turns at -43, under them all.
    */
    readonly property var trims: ({
        "saturn-opening": 3, "neptune-opening": 4.5, "terra-opening": -2.5,
        "saturn-moment": 2, "neptune-moment": 4,
        "saturn-turn": 2.5, "mercury-turn": 2, "luna-turn": -2.5,
        "neptune-lit": -4, "saturn-lit": 3.5, "mercury-lit": 4, "terra-lit": -1.5
    })
    /** The share `share` of the level for this flavour's `kind` of sting, with its trim. */
    function stingVolume(kind, share) { return Math.min(1, share * level * Math.pow(10, (trims[Theme.flavour + "-" + kind] || 0) / 20)) }
    property SoundEffect turnSound: SoundEffect { source: sounds.sting + "turn.wav"; volume: sounds.stingVolume("turn", 0.5) }
    property SoundEffect openingSound: SoundEffect { source: sounds.sting + "opening.wav"; volume: sounds.stingVolume("opening", 0.8) * sounds.openingLeft }
    /** How much of the opening's sting is left to hear, 1 → 0 as it is hushed (`hushOpening`). */
    property real openingLeft: 1
    property NumberAnimation hushing: NumberAnimation {
        target: sounds; property: "openingLeft"; to: 0; duration: Theme.fade; easing: Theme.easeIn
        onFinished: { sounds.openingSound.stop(); sounds.openingLeft = 1 }
    }
    property SoundEffect momentSound: SoundEffect { source: sounds.sting + "moment.wav"; volume: sounds.stingVolume("moment", 0.8) }
    property SoundEffect openSound: SoundEffect { source: "../assets/sounds/open.wav"; volume: 0.6 * sounds.level }
    property SoundEffect closeSound: SoundEffect { source: "../assets/sounds/close.wav"; volume: 0.6 * sounds.level }
    property SoundEffect focusSound: SoundEffect { source: "../assets/sounds/focus.wav"; volume: 0.5 * sounds.level }
    property SoundEffect errorSound: SoundEffect { source: "../assets/sounds/error.wav"; volume: 0.7 * sounds.level }
    /** The flavours with a sting for something catching (`<flavour>-lit.wav`): Neptune's neon tube, Saturn's projector lamp, Mercury's seal pressed into paper, Terra's furin in the wind. */
    readonly property var lights: ["neptune", "saturn", "mercury", "terra"]
    property SoundEffect litSound: SoundEffect { source: sounds.lights.indexOf(Theme.flavour) >= 0 ? sounds.sting + "lit.wav" : ""; volume: sounds.stingVolume("lit", 0.7) }

    readonly property bool playing: on && Theme.alive
    // The burst limiter: what played last and how weighty it was, and the sounds of the last second.
    property real lastAt: 0
    property int lastWeight: -1
    property var lastSecond: []
    /** Whether a sound of `weight` may play now: not on the heels of one as weighty or weightier, nor a seventh in a second. */
    function allowed(weight) {
        const now = Date.now()
        lastSecond = lastSecond.filter(t => now - t < 1000)
        if (lastSecond.length >= 6) return false
        if (now - lastAt < 90 && weight <= lastWeight) return false
        lastAt = now
        lastWeight = weight
        lastSecond = lastSecond.concat([now])
        return true
    }
    /** When the pointer last pressed (the window's), so moving focus by a click makes no sound. */
    property real pressedAt: 0
    /** A page turning: the flavour's sting, quiet; pages turned in quick succession sound once in `turnRest`. */
    function turn() {
        const now = Date.now()
        if (!playing || now - turnAt < turnRest || !allowed(3)) return
        turnAt = now
        turnSound.play()
    }
    property real turnAt: 0
    readonly property int turnRest: 1200
    /** The world's opening: its sting, with the slam. */
    function opening() { if (playing && allowed(4)) { hushing.stop(); openingLeft = 1; openingSound.play() } }
    /** An opening skipped: its sting fades out over `fade` rather than ringing on under what was pressed. */
    function hushOpening() { if (openingSound.playing && !hushing.running) hushing.restart() }
    /** A moment: the flavour's sting as its title slams in. */
    function moment() { if (playing && allowed(4)) momentSound.play() }
    /** The palette or a sheet opening, and closing. */
    function open() { if (playing && allowed(2)) openSound.play() }
    function close() { if (playing && allowed(2)) closeSound.play() }
    /** The keys moving on to the next thing (not a click's focus): the softest click. */
    function focus() { if (playing && Date.now() - pressedAt > 300 && allowed(0)) focusSound.play() }
    /** A light coming on: a sign catching (the opening's, Triton's ON AIR); nothing in a flavour without one. */
    function lit() { if (playing && lights.indexOf(Theme.flavour) >= 0 && allowed(3)) litSound.play() }
    /** Something went wrong (a notice of a failure). */
    function error() { if (playing && allowed(3)) errorSound.play() }
    // When each last played, so presses in a burst tick once and a voice replaces a "done".
    property real tickAt: 0
    property real doneAt: 0
    property real voiceAt: 0
    function tick() {
        const now = Date.now()
        if (!playing || now - tickAt < 60 || !allowed(1)) return
        tickAt = now
        tickSound.play()
    }
    function done() {
        const now = Date.now()
        if (!playing || now - voiceAt < 500) return
        doneAt = now
        doneSound.play()
    }
    function off() { if (playing) offSound.play() }
    function chime() { if (playing) chimeSound.play() }
    /** The world's own voice, for its main good moment (a world without one gets `done`). */
    function voice() {
        if (!playing) return
        const now = Date.now()
        voiceAt = now
        if (!voiceName) { doneSound.play(); return }
        if (now - doneAt < 500) doneSound.stop()
        voiceSound.play()
    }
}
