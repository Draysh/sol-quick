pragma ComponentBehavior: Bound
import QtQuick
import Sol.Design

/*
    A page with tabs (`/tabs`, a child of Panels in the sidebar): the
    PageHead's tabs, each part of the page's path (`/tabs?tab=calendar`),
    so the palette finds them ("Go to Tabs · Calendar") and Back
    comes back to the tab it left.
*/
Screen {
    id: page

    title: "Tabs"
    readonly property string tab: head.current

    header: PageHead {
        id: head
        title: "Tabs"
        lead: "Each tab is part of the page’s path"
        tabs: [{ id: "overview", label: "Overview" }, { id: "calendar", label: "Calendar", count: 3 }, { id: "timeline", label: "Timeline", hint: "What happened, newest first" }]
        tab: page.params.tab || ""
    }

    Grid {
        width: parent.width
        min: 300
        Card {
            title: "On this tab"
            DataRows { width: parent.width; rows: [{ label: "Tab", value: page.tab }, { label: "Path", value: "/tabs" + (page.params.tab ? "?tab=" + page.params.tab : ""), keepCase: true }] }
        }
        Card {
            title: page.tab === "overview" ? "Overview" : page.tab === "calendar" ? "Calendar" : "Timeline"
            Words {
                width: parent.width
                quiet: true
                text: page.tab === "overview" ? "The first tab: the page opened without one."
                    : page.tab === "calendar" ? "Three things this week. Choosing a tab changes this step of the history, not a new one."
                    : "The line under the tabs slid here; with less motion it is here at once."
            }
        }
    }
}
