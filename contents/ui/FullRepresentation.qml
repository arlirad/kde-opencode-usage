pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    required property UsageProvider provider

    signal configureRequested()

    implicitWidth: Kirigami.Units.gridUnit * 20
    implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2
    Layout.minimumWidth: Kirigami.Units.gridUnit * 14
    Layout.minimumHeight: implicitHeight
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            visible: root.provider.hasKey

            PlasmaComponents3.Button {
                text: root.provider.state === "error" ? "Retry" : "Refresh"
                icon.name: "view-refresh"
                enabled: !root.provider.loading
                onClicked: root.provider.refresh()
            }

            Item {
                Layout.fillWidth: true
            }
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            visible: root.provider.state === "setup"
            text: "OpenCode Go API key is not configured."
            wrapMode: Text.WordWrap
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            visible: root.provider.state === "setup"
            text: "Add your API key in the widget settings to load live usage."
            wrapMode: Text.WordWrap
        }

        PlasmaComponents3.Button {
            visible: root.provider.state === "setup"
            text: "Open Settings"
            icon.name: "configure"
            onClicked: root.configureRequested()
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            visible: root.provider.state === "demo"
            text: "Showing sample data. Add an API key in the widget settings to load live usage."
            wrapMode: Text.WordWrap
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            visible: root.provider.errorText.length > 0
            text: root.provider.errorText
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.provider.windows

            delegate: UsageRow {
                id: row

                required property string label
                required property real usedPercent
                required property real resetsAt

                Layout.fillWidth: true
                title: row.label
                percentText: root.provider.formatUsagePercentOrPlaceholder(row.usedPercent)
                resetText: root.provider.formatResetAt(row.resetsAt)
                ratio: root.provider.hasData ? root.provider.usageRatio(row.usedPercent) : 0
            }
        }
    }
}
