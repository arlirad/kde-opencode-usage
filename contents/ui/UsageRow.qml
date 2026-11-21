import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string title: ""
    property string percentText: ""
    property string resetText: ""
    property real ratio: 0

    readonly property real clampedRatio: Math.max(0, Math.min(1, ratio))
    readonly property real topLineSpacing: Kirigami.Units.smallSpacing
    readonly property bool stackedLayout: width < Kirigami.Units.gridUnit * 17

    implicitWidth: Kirigami.Units.gridUnit * 14
    implicitHeight: layout.implicitHeight

    Accessible.role: Accessible.Grouping
    Accessible.name: root.title + ", " + root.percentText + ", " + root.resetText

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Math.round(Kirigami.Units.smallSpacing * 0.6)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.topLineSpacing

            Text {
                id: titleLabel

                Layout.preferredWidth: implicitWidth
                Layout.minimumWidth: 0
                text: root.title
                color: Kirigami.Theme.textColor
                font: Kirigami.Theme.defaultFont
                elide: Text.ElideRight
                Accessible.ignored: true
            }

            UsageBadge {
                id: usageBadge

                Layout.preferredWidth: implicitWidth
                Layout.minimumWidth: implicitWidth
                text: root.percentText
                Accessible.ignored: true
            }

            Item {
                Layout.fillWidth: true
                implicitWidth: 0
            }

            UsageResetLabel {
                visible: !root.stackedLayout
                Layout.preferredWidth: implicitWidth
                text: root.resetText
            }
        }

        UsageResetLabel {
            visible: root.stackedLayout
            Layout.fillWidth: true
            text: root.resetText
        }

        UsageBar {
            Layout.fillWidth: true
            ratio: root.clampedRatio
        }
    }
}
