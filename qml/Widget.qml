import QtQuick

/*
    Draws a widget from a `WidgetView`: a figure with a caption, a
    progress, items (ticks where `done` is set), rows, or an empty line.

        Widget { view: todayView; onToggle: (item, done) => … }
*/
Column {
    id: root

    property var view: ({})
    property string world: Sol.world
    /** Called when a box is ticked; return a promise to show it failed. */
    property var onToggle: null
    property string busy: ""

    spacing: Theme.s3

    Row {
        visible: !!root.view.figure
        spacing: Theme.s3
        Display { value: Number(root.view.figure) || 0; format: v => root.view.figure && isNaN(Number(root.view.figure)) ? root.view.figure : String(Math.round(v)) }
        Quiet { visible: !!root.view.caption; text: root.view.caption || ""; anchors.baseline: parent.children[0].baseline }
    }
    Progress { visible: !!root.view.progress; width: parent.width; value: root.view.progress ? root.view.progress.value : 0; max: root.view.progress ? root.view.progress.max : 1 }
    Column {
        visible: !!root.view.items && root.view.items.length > 0
        width: parent.width
        Repeater {
            model: root.view.items || []
            delegate: Item {
                required property var modelData
                required property int index
                width: root.width
                height: modelData.done !== undefined && modelData.done !== null ? 46 : 40
                Check {
                    visible: modelData.done !== undefined && modelData.done !== null
                    width: parent.width
                    label: modelData.label
                    meta: modelData.meta || ""
                    checked: !!modelData.done
                    busy: root.busy === modelData.id
                    enabled: !!modelData.toggle && !!root.onToggle
                    last: index === (root.view.items || []).length - 1
                    onToggled: done => {
                        root.busy = modelData.id
                        Promise.resolve(root.onToggle(modelData.id, done)).catch(why => Notices.failed(root.world, "Not saved", why)).finally(() => root.busy = "")
                    }
                }
                Item {
                    visible: modelData.done === undefined || modelData.done === null
                    anchors.fill: parent
                    Words { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; width: parent.width - 100; elide: Text.ElideRight }
                    Quiet { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.meta || "" }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }
                }
            }
        }
    }
    DataRows { visible: !!root.view.rows && root.view.rows.length > 0; width: parent.width; rows: root.view.rows || [] }
    Words { visible: !root.view.figure && !(root.view.items && root.view.items.length) && !(root.view.rows && root.view.rows.length) && !!root.view.empty; small: true; quiet: true; width: parent.width; text: root.view.empty || "" }
}
