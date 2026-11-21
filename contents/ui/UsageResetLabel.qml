import QtQuick
import org.kde.kirigami as Kirigami

Text {
    color: Kirigami.Theme.textColor
    opacity: 0.72
    font: Kirigami.Theme.smallFont
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideRight
    Accessible.ignored: true
}
