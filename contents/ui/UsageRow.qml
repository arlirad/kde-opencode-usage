import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    property string title: ""
    property string percentText: ""
    property string resetText: ""
    property real ratio: 0

    readonly property real clampedRatio: Math.max(0, Math.min(1, ratio))
    readonly property bool stackedLayout: width < Kirigami.Units.gridUnit * 17

    implicitWidth: Kirigami.Units.gridUnit * 14
    implicitHeight: layout.implicitHeight

    Accessible.role: Accessible.Grouping
    Accessible.name: root.title + ", " + root.percentText + ", " + root.resetText

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                Layout.preferredWidth: implicitWidth
                Layout.minimumWidth: 0
                text: root.title
                elide: Text.ElideRight
                Accessible.ignored: true
            }

            PlasmaComponents3.Label {
                text: root.percentText
                Accessible.ignored: true
            }

            Item {
                Layout.fillWidth: true
                implicitWidth: 0
            }

            PlasmaComponents3.Label {
                visible: !root.stackedLayout
                Layout.preferredWidth: implicitWidth
                text: root.resetText
                horizontalAlignment: Text.AlignRight
                Accessible.ignored: true
            }
        }

        PlasmaComponents3.Label {
            visible: root.stackedLayout
            Layout.fillWidth: true
            text: root.resetText
            horizontalAlignment: Text.AlignRight
            Accessible.ignored: true
        }

        PlasmaComponents3.ProgressBar {
            Layout.fillWidth: true
            value: root.clampedRatio
            Accessible.ignored: true
        }
    }
}
