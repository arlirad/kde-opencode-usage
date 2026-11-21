import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../contents/ui" as UsageUi

TestCase {
    id: testCase

    name: "CompactActivation"
    when: windowShown
    width: 240
    height: 120
    visible: true

    readonly property var sampleProvider: UsageUi.UsageProvider {}

    QtObject {
        id: applet

        property bool expanded: false
    }

    UsageUi.CompactRepresentation {
        id: compact

        width: 54
        height: 36
        visible: true
        provider: testCase.sampleProvider
        plasmoidItem: applet
    }

    function channel(value) {
        const channelValue = value / 255
        return channelValue <= 0.04045 ? channelValue / 12.92 : Math.pow((channelValue + 0.055) / 1.055, 2.4)
    }

    function luminance(color) {
        return 0.2126 * channel(color.r * 255) + 0.7152 * channel(color.g * 255) + 0.0722 * channel(color.b * 255)
    }

    function contrast(first, second) {
        const firstLuminance = luminance(first)
        const secondLuminance = luminance(second)
        return (Math.max(firstLuminance, secondLuminance) + 0.05) / (Math.min(firstLuminance, secondLuminance) + 0.05)
    }

    function cleanup() {
        applet.expanded = false
    }

    function test_clickSignalOpensFullView() {
        compact.clicked()
        compare(applet.expanded, true)
    }

    function test_mouseClickTogglesExpanded() {
        verify(compact.visible)
        verify(compact.enabled)
        mouseClick(testCase, compact.x + compact.width / 2, compact.y + compact.height / 2)
        compare(applet.expanded, true)
        mouseClick(testCase, compact.x + compact.width / 2, compact.y + compact.height / 2)
        compare(applet.expanded, false)
    }

    function test_keyboardTogglesExpanded() {
        compact.forceActiveFocus()
        compare(compact.activeFocus, true)
        keyClick(Qt.Key_Space)
        compare(applet.expanded, true)
        keyClick(Qt.Key_Return)
        compare(applet.expanded, false)
    }

    function test_focusIndicatorContrast() {
        compact.forceActiveFocus()
        verify(compact.activeFocus)
        verify(compact.showFocusRing)
        verify(contrast(compact.focusRingColor, Kirigami.Theme.backgroundColor) >= 3)
    }
}
