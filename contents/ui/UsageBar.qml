import QtQuick
import org.kde.kirigami as Kirigami
import "UsagePalette.js" as UsagePalette

Item {
    id: root

    property real ratio: 0

    readonly property real clampedRatio: Math.max(0, Math.min(1, ratio))
    readonly property color trackColor: UsagePalette.trackColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor)
    readonly property color fillColor: UsagePalette.readableAccent(Kirigami.Theme.highlightColor, root.trackColor, Kirigami.Theme.textColor)

    implicitHeight: Math.max(4, Math.round(Kirigami.Units.smallSpacing * 0.6))
    Accessible.ignored: true

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
    }

    Rectangle {
        width: root.clampedRatio > 0 ? Math.max(parent.height, parent.width * root.clampedRatio) : 0
        height: parent.height
        radius: height / 2
        color: root.fillColor
    }
}
