import QtQuick
import QtQuick.Dialogs
import QtCore

/*
    The Settings card that saves everything the world keeps as one file
    (in Downloads) and brings such a file back: it reads the file first,
    says what it would add and replace, and imports only once the person
    says yes. Importing merges by id and deletes nothing; it syncs like
    any other change. The file comes from the desktop's own picker (the
    portal, `pick_file`), or Qt's dialog where there is none. Runs the
    shared commands `export_world` and `import_world`. Anything inside it
    goes below its own buttons (Terra's diary as Markdown).

        ExportCard { }
*/
Card {
    id: root

    /** The world's name in the sentences. */
    property string name: Sol.manifest.name || ""
    /** The last file saved, or "". */
    property string saved: ""
    property bool exporting: false
    property bool importing: false

    title: "Export and import"

    function exportAll() {
        exporting = true
        Sol.call("export_world").then(e => {
            root.saved = e.path
            Notices.show({ world: Sol.world, title: "Exported", body: Format.plural(e.documents, "thing") + ", in " + e.path })
        }).catch(why => Sol.fail("Not exported", why)).finally(() => root.exporting = false)
    }

    // What the file would do here, in a sentence per collection.
    function summary(plan) {
        const parts = plan.collections.filter(c => c.added || c.replaced).map(c =>
            c.label + ": " + [c.added ? c.added + " new" : "", c.replaced ? c.replaced + " changed" : ""].filter(Boolean).join(", "))
        return parts.join(". ") + "." + (plan.same ? " " + Format.plural(plan.same, "thing") + " already the same." : "")
            + " Nothing here is deleted, and the changes go to your other devices too."
    }

    // The desktop's picker first; Qt's own dialog where there's no portal.
    function pick() {
        Sol.call("pick_file", { title: "Import into " + root.name, filter: { label: "Sol exports", globs: ["*.json"] } }).then(path => {
            if (path) root.review(path)
        }).catch(() => picker.open())
    }

    /** Reads the file at `path` (a path or a file:// URL), asks, then imports. */
    function review(path) {
        importing = true
        Sol.call("import_world", { path: String(path), dry: true }).then(plan => {
            if (!plan.added && !plan.replaced) {
                Notices.show({ world: Sol.world, title: "Nothing to import", body: "Everything in that file is here already." })
                return null
            }
            const ask = (root.Window.window as AppWindow).ask
            const title = "Import " + [plan.added ? plan.added + " new" : "", plan.replaced ? plan.replaced + " changed" : ""].filter(Boolean).join(" and ")
            return ask.confirm(title, root.summary(plan), "Import").then(yes => yes
                ? Sol.call("import_world", { path: String(path) }).then(done =>
                    Notices.show({ world: Sol.world, title: "Imported", body: Format.plural(done.added, "thing") + " added, " + done.replaced + " replaced." }))
                : null)
        }).catch(why => Sol.fail("Not imported", why)).finally(() => root.importing = false)
    }

    Words {
        width: parent.width; small: true; quiet: true
        text: "Everything " + root.name + " keeps, as one file to keep or bring back on any device. Importing adds what’s missing and replaces what differs; it never deletes."
    }
    DataRows {
        visible: root.saved !== ""
        width: parent.width
        rows: root.saved ? [{ label: "Saved", value: root.saved, keepCase: true }] : []
    }
    Flow {
        width: parent.width
        spacing: Theme.s2
        Button { icon: "download"; text: root.saved ? "Export again" : "Export everything"; busy: root.exporting; onClicked: root.exportAll() }
        Button { variant: "quiet"; icon: "upload"; text: "Import a file…"; busy: root.importing; onClicked: root.pick() }
    }

    FileDialog {
        id: picker
        title: "Import into " + root.name
        nameFilters: ["Sol exports (*.json)", "All files (*)"]
        currentFolder: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
        onAccepted: root.review(selectedFile.toString())
    }
}
