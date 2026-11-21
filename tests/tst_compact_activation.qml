import QtQuick
import QtTest
import "../contents/ui" as UsageUi

TestCase {
    id: testCase

    name: "CompactActivation"
    when: windowShown
    width: 240
    height: 120
    visible: true

    readonly property var testProvider: UsageUi.UsageProvider {}

    QtObject {
        id: applet

        property bool expanded: false
    }

    UsageUi.CompactRepresentation {
        id: compact

        width: 54
        height: 36
        visible: true
        provider: testCase.testProvider
        plasmoidItem: applet
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
}
