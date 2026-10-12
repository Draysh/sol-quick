pragma Singleton
import QtQuick
import QtCore
import QtMultimedia

/*
    Tiny sounds, a few milliseconds each, for a tick, a thing done, and a
    thing taken back; a soft chime, two seconds, for a moment; and the
    world's own voice (Saturn's soft ring, Neptune's water drop, Mercury's
    bell, Terra's wood tick, Luna's chime, Titan's whoosh, Triton's static
    blip, made by `scripts/world-sounds.py`) for its main good moment only:
    an episode watched, a right answer, a habit done. Off by default on a
    device until turned on in a Settings page's DeviceCard (one switch for
    all of them); never while the window is asleep.

        Sounds.tick()   Sounds.done()   Sounds.off()   Sounds.chime()   Sounds.voice()
*/
QtObject {
    id: sounds

    component Prefs: Settings { property bool sounds: false }
    property Prefs prefs: Prefs { category: "sol.device" }
    readonly property bool on: prefs.sounds
    function setOn(v) { prefs.sounds = v; if (v) tick() }

    property SoundEffect tickSound: SoundEffect { source: "../assets/sounds/tick.wav"; volume: 0.5 }
    property SoundEffect doneSound: SoundEffect { source: "../assets/sounds/done.wav"; volume: 0.45 }
    property SoundEffect offSound: SoundEffect { source: "../assets/sounds/off.wav"; volume: 0.4 }
    property SoundEffect chimeSound: SoundEffect { source: "../assets/sounds/chime.wav"; volume: 0.3 }

    /** The worlds with a voice of their own, and what it sounds like (DeviceCard says). */
    readonly property var voices: ({ saturn: "a soft ring", neptune: "a water drop", mercury: "a bell", terra: "a wood tick", luna: "a chime", titan: "a whoosh", triton: "a static blip" })
    /** What this world's voice sounds like, or "" for a world without one. */
    /** Whose voice: the world of the page in front (the Shell sets it: a carried moon's own on its pages). */
    property string world: Sol.world
    readonly property string voiceName: voices[world] || ""
    property SoundEffect voiceSound: SoundEffect { source: sounds.voiceName ? "../assets/sounds/" + sounds.world + ".wav" : ""; volume: 0.4 }

    function tick() { if (on && Theme.alive) tickSound.play() }
    function done() { if (on && Theme.alive) doneSound.play() }
    function off() { if (on && Theme.alive) offSound.play() }
    function chime() { if (on && Theme.alive) chimeSound.play() }
    /** The world's own voice, for its main good moment (a world without one gets `done`). */
    function voice() { if (!on || !Theme.alive) return; if (voiceName) voiceSound.play(); else doneSound.play() }
}
