import QtQuick
import QtCore

/*
    A world's own settings on this device (QtCore's Settings), where its
    app keeps them: the app's own file, or, for a moon carried in its
    planet's app, the file the moon's own app kept them in
    (`~/.config/sachi.digital/Luna.conf`), so nothing set there is lost.

        component Prefs: WorldSettings { world: "luna"; property bool nightSounds: true }
*/
Settings {
    /** The world whose settings these are: a moon the app carries, or the app's own. */
    property string world: Sol.world
    category: "sol." + world
    location: Sol.own(world) ? "" : StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/sachi.digital/" + Worlds.get(world).name + ".conf"
}
