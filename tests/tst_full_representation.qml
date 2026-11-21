import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../contents/ui" as UsageUi

TestCase {
    id: testCase

    name: "FullRepresentation"
    when: windowShown
    width: 400
    height: 700
    visible: true

    readonly property real nowMs: Date.parse("2026-05-01T12:00:00Z")

    UsageUi.UsageProvider {
        id: testProvider
    }

    UsageUi.FullRepresentation {
        id: full

        width: Kirigami.Units.gridUnit * 20
        height: Kirigami.Units.gridUnit * 32
        visible: true
        provider: testProvider
    }

    function cleanup() {
        testProvider.apiKey = ""
        testProvider.client.abort()
        testProvider.resetWindows()
        testProvider.errorText = ""
        testProvider.nowMs = Date.now()
        full.width = Kirigami.Units.gridUnit * 20
        full.height = Kirigami.Units.gridUnit * 32
    }

    function loadLiveData() {
        testProvider.apiKey = "test-key-not-real"
        testProvider.nowMs = testCase.nowMs
        testProvider.applyResponse(200, JSON.stringify({
            usage: {
                rolling: { percent: 40, resetsAt: "2026-05-01T13:00:00Z" },
                weekly: { percent: 20, resetsAt: "2026-05-02T12:00:00Z" },
                monthly: { percent: 10, resetsAt: "2026-06-01T12:00:00Z" }
            }
        }), testCase.nowMs)
    }

    function test_refreshButtonFillsWidthBelowRows() {
        loadLiveData()
        full.width = Kirigami.Units.gridUnit * 20
        waitForRendering(full)

        const layout = findChild(full, "contentLayout")
        const button = findChild(full, "refreshButton")
        const rows = findChild(full, "rowsRepeater")

        compare(rows.count, 3)
        compare(button.visible, true)
        compare(button.text, "Refresh")
        compare(Math.round(button.width), Math.round(layout.width))

        const lastRow = rows.itemAt(2)
        verify(button.y >= lastRow.y + lastRow.height)
    }

    function test_narrowWidthKeepsRowLabelsAndButtonText() {
        loadLiveData()
        full.width = Kirigami.Units.gridUnit * 14
        waitForRendering(full)

        const layout = findChild(full, "contentLayout")
        const button = findChild(full, "refreshButton")
        const rows = findChild(full, "rowsRepeater")

        compare(button.visible, true)
        compare(button.text, "Refresh")
        compare(Math.round(button.width), Math.round(layout.width))
        verify(button.width > 0)

        compare(rows.itemAt(0).title, "5-hour window")
        compare(rows.itemAt(0).percentText, "40% used")
        compare(rows.itemAt(1).title, "Weekly")
        compare(rows.itemAt(1).percentText, "20% used")
        compare(rows.itemAt(2).title, "Monthly")
        compare(rows.itemAt(2).percentText, "10% used")

        for (let index = 0; index < rows.count; ++index) {
            verify(rows.itemAt(index).width <= layout.width + 0.5)
        }
    }

    function test_retryButtonFollowsErrorContent() {
        loadLiveData()
        testProvider.applyResponse(500, "", testCase.nowMs)
        full.width = Kirigami.Units.gridUnit * 20
        waitForRendering(full)

        const button = findChild(full, "refreshButton")
        const errorLabel = findChild(full, "errorLabel")
        const rows = findChild(full, "rowsRepeater")

        compare(button.text, "Retry")
        compare(errorLabel.visible, true)
        verify(button.y >= errorLabel.y + errorLabel.height)
        verify(button.y >= rows.itemAt(2).y + rows.itemAt(2).height)
    }

    function test_setupShowsPlaceholdersWithoutRefresh() {
        full.width = Kirigami.Units.gridUnit * 20
        waitForRendering(full)

        const button = findChild(full, "refreshButton")
        const setupLabel = findChild(full, "setupLabel")
        const rows = findChild(full, "rowsRepeater")

        compare(testProvider.state, "setup")
        compare(button.visible, false)
        compare(setupLabel.visible, true)
        verify(setupLabel.text.indexOf("API key") >= 0)

        for (let index = 0; index < rows.count; ++index) {
            compare(rows.itemAt(index).percentText, "—")
            compare(rows.itemAt(index).resetText, "—")
        }
    }
}
