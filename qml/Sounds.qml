pragma Singleton
import QtQuick
import QtCore
import QtMultimedia

/*
    Tiny sounds, a few milliseconds each, for a press (a button, a tab, a
    switch, a box ticked), a thing done (a write that went through), and a
    thing taken back; a soft chime, two seconds, for a moment; and the
    world's own voice (Saturn's soft ring, Neptune's water drop, Mercury's
    bell, Terra's wood tick, Luna's chime, Titan's whoosh, Triton's static
    blip, made by `scripts/world-sounds.py`) for its main good moment only:
    an episode watched, a right answer, a habit done. On by default and
    low (`level`), so they sit under whatever else is playing; one switch
    in a Settings page's DeviceCard turns them all off on a device (a
    device that has said already keeps what it said). Never while the
    window is asleep, and never two over each other: the voice takes the
    place of a "done" just played, and a burst of presses ticks once.

        Sounds.tick()   Sounds.done()   Sounds.off()   Sounds.chime()   Sounds.voice()
*/
QtObject {
    id: sounds

    component Prefs: Settings { property bool sounds: true }
    property Prefs prefs: Prefs { category: "sol.device" }
    readonly property bool on: prefs.sounds
    function setOn(v) { prefs.sounds = v; if (v) tick() }

    /** How loud they all are, 0 to 1: low, under music and speech. Each sound's own volume is its share of it. */
    readonly property real level: 0.5
    property SoundEffect tickSound: SoundEffect { source: "../assets/sounds/tick.wav"; volume: 0.45 * sounds.level }
    property SoundEffect doneSound: SoundEffect { source: "../assets/sounds/done.wav"; volume: 0.5 * sounds.level }
    property SoundEffect offSound: SoundEffect { source: "../assets/sounds/off.wav"; volume: 0.4 * sounds.level }
    property SoundEffect chimeSound: SoundEffect { source: "../assets/sounds/chime.wav"; volume: 0.4 * sounds.level }

    /** The worlds with a voice of their own, and what it sounds like (DeviceCard says). */
    readonly property var voices: ({ saturn: "a soft ring", neptune: "a water drop", mercury: "a bell", terra: "a wood tick", luna: "a chime", titan: "a whoosh", triton: "a static blip" })
    /** What this world's voice sounds like, or "" for a world without one. */
    /** Whose voice: the world of the page in front (the Shell sets it: a carried moon's own on its pages). */
    property string world: Sol.world
    readonly property string voiceName: voices[world] || ""
    property SoundEffect voiceSound: SoundEffect { source: sounds.voiceName ? "../assets/sounds/" + sounds.world + ".wav" : ""; volume: 0.8 * sounds.level }

    readonly property bool playing: on && Theme.alive
    // When each last played, so presses in a burst tick once and a voice replaces a "done".
    property real tickAt: 0
    property real doneAt: 0
    property real voiceAt: 0
    function tick() {
        const now = Date.now()
        if (!playing || now - tickAt < 60) return
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
