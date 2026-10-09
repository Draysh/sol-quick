pragma Singleton
import QtQuick
import QtCore
import QtMultimedia

/*
    Tiny sounds, a few milliseconds each, for a tick, a thing done, and a
    thing taken back. Off by default on a device until turned on in a
    Settings page's DeviceCard; never while the window is asleep.

        Sounds.tick()   Sounds.done()   Sounds.off()
*/
QtObject {
    id: sounds

    property Settings prefs: Settings { category: "sol.device"; property bool sounds: false }
    readonly property bool on: prefs.sounds
    function setOn(v) { prefs.sounds = v; if (v) tick() }

    property SoundEffect tickSound: SoundEffect { source: "../assets/sounds/tick.wav"; volume: 0.5 }
    property SoundEffect doneSound: SoundEffect { source: "../assets/sounds/done.wav"; volume: 0.45 }
    property SoundEffect offSound: SoundEffect { source: "../assets/sounds/off.wav"; volume: 0.4 }

    function tick() { if (on && Theme.alive) tickSound.play() }
    function done() { if (on && Theme.alive) doneSound.play() }
    function off() { if (on && Theme.alive) offSound.play() }
}
