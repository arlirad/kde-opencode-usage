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
    readonly property var highlightedWindow: highlightedIndex >= 0 ? root.provider.windows.get(highlightedIndex) : null

    implicitWidth: Kirigami.Units.gridUnit * 3
    implicitHeight: Kirigami.Units.gridUnit * 2
    Layout.minimumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight

    readonly property color focusRingColor: Kirigami.Theme.textColor
    readonly property bool showFocusRing: root.activeFocus

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

    contentItem: Item {
        Rectangle {
            anchors.fill: parent
            radius: Math.round(Kirigami.Units.gridUnit * 0.35)
            color: Kirigami.Theme.backgroundColor
            border.width: root.showFocusRing ? 2 : 1
            border.color: root.showFocusRing ? root.focusRingColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.max(3, Math.round(Kirigami.Units.smallSpacing * 0.5))
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.highlightedWindow ? root.provider.formatPercent(root.highlightedWindow.usedPercent) : "—"
                color: Kirigami.Theme.textColor
                font: Kirigami.Theme.defaultFont
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                Accessible.ignored: true
            }

            Repeater {
                model: root.provider.windows

                delegate: UsageBar {
                    required property real usedPercent

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(2, Math.round(Kirigami.Units.smallSpacing * 0.35))
                    ratio: root.provider.usageRatio(usedPercent)
                }
            }
        }
    }
}
