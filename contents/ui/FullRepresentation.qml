pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    required property UsageProvider provider

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

        Repeater {
            model: root.provider.windows

            delegate: UsageRow {
                id: row

                required property string label
                required property real usedPercent
                required property int resetsInSeconds

                Layout.fillWidth: true
                title: row.label
                percentText: root.provider.formatUsagePercent(row.usedPercent)
                resetText: root.provider.formatReset(row.resetsInSeconds)
                ratio: root.provider.usageRatio(row.usedPercent)
            }
        }
    }
}
