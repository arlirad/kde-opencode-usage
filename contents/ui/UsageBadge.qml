import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property string text: ""

    implicitWidth: label.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: label.implicitHeight + Math.round(Kirigami.Units.smallSpacing * 0.8)
    radius: height / 2
    color: "transparent"
    border.width: 1
    border.color: Kirigami.Theme.positiveTextColor

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: Kirigami.Theme.textColor
        font: Kirigami.Theme.smallFont
        Accessible.ignored: true
    }
}
