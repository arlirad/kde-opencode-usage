import QtQuick
import QtTest
import "../contents/ui" as UsageUi

TestCase {
    id: testCase

    name: "UsageProvider"
    when: windowShown

    readonly property real nowMs: Date.parse("2026-05-01T12:00:00Z")

    UsageUi.UsageProvider {
        id: provider
    }

    function cleanup() {
        provider.apiKey = ""
        provider.demoMode = false
        provider.client.abort()
        provider.resetWindows()
        provider.errorText = ""
        provider.pollIntervalMinutes = 5
        provider.nowMs = Date.now()
    }

    function test_setupStateWithoutKey() {
        compare(provider.hasKey, false)
        compare(provider.state, "setup")
        compare(provider.hasData, false)
        compare(provider.windows.count, 3)
        compare(provider.windows.get(0).label, "5-hour window")
        compare(provider.windows.get(1).label, "Weekly")
        compare(provider.windows.get(2).label, "Monthly")
        compare(provider.formatUsagePercentOrPlaceholder(0), "—")
        verify(provider.summaryText().indexOf("API key") >= 0)

        provider.refresh()
        compare(provider.loading, false)
        compare(provider.client.busy, false)
    }

    function test_keyConfiguredWaitsForExplicitFetch() {
        provider.apiKey = "test-key-not-real"

        compare(provider.hasKey, true)
        compare(provider.loading, false)
        compare(provider.hasData, false)
        compare(provider.state, "loading")
        compare(provider.client.busy, false)
    }

    function test_successfulResponseMapsRows() {
        provider.apiKey = "test-key-not-real"
        provider.nowMs = testCase.nowMs
        provider.applyResponse(200, JSON.stringify({
            usage: {
                rolling: { status: "ok", percent: 12.5, resetsAt: "2026-05-01T14:00:00Z" },
                weekly: { status: "ok", percent: 99, resetsAt: "2026-05-03T12:00:00Z" },
                monthly: { status: "ok", percent: 5, resetsAt: "2026-06-01T12:00:00Z" }
            }
        }), testCase.nowMs)

        compare(provider.state, "ready")
        compare(provider.hasData, true)
        compare(provider.isSampleData, false)
        compare(provider.windows.count, 3)
        compare(provider.windows.get(0).windowId, "five_hour")
        compare(provider.windows.get(0).usedPercent, 12.5)
        compare(provider.windows.get(0).resetsInSeconds, 7200)
        compare(provider.formatUsagePercentOrPlaceholder(provider.windows.get(0).usedPercent), "13% used")
        compare(provider.formatResetAt(provider.windows.get(0).resetsAt), "Resets in 2h")
        compare(provider.windows.get(1).usedPercent, 99)
        compare(provider.windows.get(2).label, "Monthly")
    }

    function test_errorAfterSuccessKeepsLiveDataAndHidesKey() {
        provider.apiKey = "test-key-not-real"
        provider.nowMs = testCase.nowMs
        provider.applyResponse(200, JSON.stringify({
            usage: {
                rolling: { percent: 40, resetsAt: "2026-05-01T13:00:00Z" },
                weekly: { percent: 20, resetsAt: "2026-05-02T12:00:00Z" },
                monthly: { percent: 10, resetsAt: "2026-06-01T12:00:00Z" }
            }
        }), testCase.nowMs)
        provider.applyResponse(401, "", testCase.nowMs)

        compare(provider.state, "error")
        compare(provider.loading, false)
        compare(provider.hasData, true)
        compare(provider.windows.get(0).usedPercent, 40)
        verify(provider.errorText.indexOf("key rejected") >= 0)
        verify(provider.summaryText().indexOf("Update failed") >= 0)
        compare(provider.summaryText().indexOf("test-key-not-real"), -1)
    }

    function test_malformedResponseIsAnError() {
        provider.apiKey = "test-key-not-real"
        provider.applyResponse(200, "{", testCase.nowMs)

        compare(provider.state, "error")
        compare(provider.hasData, false)
        verify(provider.errorText.indexOf("Invalid JSON") >= 0)
        compare(provider.windows.count, 3)
        compare(provider.windows.get(0).usedPercent, 0)
        compare(provider.formatUsagePercentOrPlaceholder(0), "—")
    }

    function test_networkFailureIsAnError() {
        provider.apiKey = "test-key-not-real"
        provider.handleFailure("Request timed out.")

        compare(provider.state, "error")
        compare(provider.loading, false)
        verify(provider.errorText.indexOf("timed out") >= 0)
    }

    function test_pollIntervalIsConfigurable() {
        provider.pollIntervalMinutes = 7
        compare(provider.pollTimer.interval, 420000)

        provider.pollIntervalMinutes = 0
        compare(provider.pollTimer.interval, 60000)
    }

    function test_resetCountdownTracksCurrentTime() {
        provider.nowMs = testCase.nowMs
        compare(provider.formatResetAt(testCase.nowMs + 3600000), "Resets in 1h")

        provider.nowMs = testCase.nowMs + 1800000
        compare(provider.formatResetAt(testCase.nowMs + 3600000), "Resets in 30m")

        compare(provider.formatResetAt(0), "—")
    }

    function test_demoModeIsOnlyUsedWithoutKey() {
        provider.demoMode = true

        compare(provider.state, "demo")
        compare(provider.isSampleData, true)
        compare(provider.hasData, true)
        compare(provider.windows.count, 3)
        compare(provider.windows.get(0).usedPercent, 10)
        compare(provider.windows.get(1).usedPercent, 4)
        compare(provider.windows.get(2).usedPercent, 2)
        verify(provider.summaryText().indexOf("Sample data") >= 0)

        provider.apiKey = "test-key-not-real"

        compare(provider.state, "loading")
        compare(provider.isSampleData, false)
        compare(provider.hasData, false)
        compare(provider.windows.get(0).usedPercent, 0)
        verify(provider.summaryText().indexOf("Sample data") < 0)
    }

    function test_failureNeverRestoresSampleData() {
        provider.demoMode = true
        compare(provider.isSampleData, true)

        provider.apiKey = "test-key-not-real"
        provider.applyResponse(500, "", testCase.nowMs)

        compare(provider.state, "error")
        compare(provider.isSampleData, false)
        compare(provider.hasData, false)
        compare(provider.windows.get(0).usedPercent, 0)
        compare(provider.windows.get(2).usedPercent, 0)
        verify(provider.errorText.indexOf("Server error") >= 0)
    }
}
