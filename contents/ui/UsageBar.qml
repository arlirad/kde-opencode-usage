import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property real ratio: 0

    readonly property real clampedRatio: Math.max(0, Math.min(1, ratio))

    implicitHeight: Math.max(4, Math.round(Kirigami.Units.smallSpacing * 0.6))
    Accessible.ignored: true

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.51)
    }

    Rectangle {
        width: root.clampedRatio > 0 ? Math.max(parent.height, parent.width * root.clampedRatio) : 0
        height: parent.height
        radius: height / 2
        color: Kirigami.Theme.textColor
    }
}
