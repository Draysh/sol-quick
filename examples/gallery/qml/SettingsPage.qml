import QtQuick
import Sol.Design

/*
    The gallery's Settings (`/settings`): the kit's system menu, its own
    parts (Sol, Export, This device, Updates) and the moon's under its
    name, plus one part of the gallery's own; `/moon/settings` opens the
    moon's.
*/
SettingsScreen {
    lead: "The kit's parts, one of the gallery's own, and the moon's under its name."
    SettingsPart {
        key: "look"
        label: "Look"
        jp: "外観"
        order: 10
        Card {
            title: "A world's own part"
            jp: "固有"
            Words { width: parent.width; small: true; quiet: true; text: "A world adds its parts as SettingsParts: a key for the path, a label, its Japanese, and its cards." }
            Field { width: parent.width; label: "A field"; placeholder: "In its bracketed well" }
            Select { width: parent.width; label: "A choice"; value: "one"; options: [{ value: "one", label: "The first" }, { value: "two", label: "The second" }] }
            Button { variant: "danger"; text: "Forget everything" }
        }
    }
}
