pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

PlasmaComponents3.AbstractButton {
    id: root

    required property UsageProvider provider
    required property var plasmoidItem

    readonly property int highlightedIndex: root.provider.highestUsageIndex()

    readonly property string displayText: {
        if (root.provider.state === "setup") {
            return "Setup"
        }
        if (!root.provider.hasData) {
            return root.provider.state === "loading" ? "…" : "—"
        }
        if (root.highlightedIndex < 0) {
            return "—"
        }
        return root.provider.formatPercent(root.provider.windows.get(root.highlightedIndex).usedPercent)
    }

    implicitWidth: Kirigami.Units.gridUnit * 3
    implicitHeight: Kirigami.Units.gridUnit * 2
    Layout.minimumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "OpenCode Usage"
    Accessible.description: root.provider.summaryText()

    function toggleExpanded() {
        root.plasmoidItem.expanded = !root.plasmoidItem.expanded
    }

    onClicked: {
        root.forceActiveFocus()
        root.toggleExpanded()
    }

    Keys.onReturnPressed: event => {
        root.toggleExpanded()
        event.accepted = true
    }

    Keys.onEnterPressed: event => {
        root.toggleExpanded()
        event.accepted = true
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: root.displayText
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            Accessible.ignored: true
        }

        Repeater {
            model: root.provider.windows

            delegate: PlasmaComponents3.ProgressBar {
                required property real usedPercent

                Layout.fillWidth: true
                value: root.provider.hasData ? root.provider.usageRatio(usedPercent) : 0
                Accessible.ignored: true
            }
        }
    }
}
