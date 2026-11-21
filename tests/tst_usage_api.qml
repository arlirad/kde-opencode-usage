import QtQuick
import QtTest
import "../contents/ui/UsageApi.js" as UsageApi

TestCase {
    id: testCase

    name: "UsageApi"

    readonly property real nowMs: Date.parse("2026-05-01T12:00:00Z")

    function test_windowsAreCanonicalAndOrdered() {
        const result = UsageApi.normalizeResponse({
            usage: {
                rolling: { status: "ok", percent: 1, resetsAt: "2026-05-01T13:00:00Z" },
                weekly: { status: "ok", percent: 2, resetsAt: "2026-05-02T12:00:00Z" },
                monthly: { status: "ok", percent: 3, resetsAt: "2026-06-01T12:00:00Z" }
            }
        }, testCase.nowMs)

        compare(result.ok, true)
        compare(result.windows.length, 3)
        compare(result.windows[0].windowId, "five_hour")
        compare(result.windows[0].label, "5-hour window")
        compare(result.windows[1].windowId, "weekly")
        compare(result.windows[1].label, "Weekly")
        compare(result.windows[2].windowId, "monthly")
        compare(result.windows[2].label, "Monthly")
    }

    function test_isoResetTimestampBecomesCountdown() {
        const result = UsageApi.normalizeResponse({
            usage: {
                rolling: { percent: 10, resetsAt: "2026-05-01T14:00:00Z" },
                weekly: { percent: 4, resetsAt: "2026-05-03T12:00:00Z" },
                monthly: { percent: 2, resetsAt: "2026-06-01T12:00:00Z" }
            }
        }, testCase.nowMs)

        compare(result.ok, true)
        compare(result.windows[0].usedPercent, 10)
        compare(result.windows[0].resetsAt, Date.parse("2026-05-01T14:00:00Z"))
        compare(result.windows[0].resetsInSeconds, 7200)
        compare(result.windows[1].resetsInSeconds, 172800)
        compare(result.windows[2].resetsInSeconds, 2678400)
    }

    function test_numericTimestampsAreAccepted() {
        const seconds = UsageApi.normalizeEntry({
            usedPercent: 5,
            resetsAt: testCase.nowMs / 1000 + 3600
        }, testCase.nowMs)
        compare(seconds.resetsAt, testCase.nowMs + 3600000)
        compare(seconds.resetsInSeconds, 3600)

        const milliseconds = UsageApi.normalizeEntry({
            usedPercent: 5,
            resetsAt: testCase.nowMs + 1800000
        }, testCase.nowMs)
        compare(milliseconds.resetsAt, testCase.nowMs + 1800000)
        compare(milliseconds.resetsInSeconds, 1800)
    }

    function test_percentIsClamped() {
        const result = UsageApi.normalizeResponse({
            usage: {
                rolling: { percent: 150, resetsAt: "2026-05-01T13:00:00Z" },
                weekly: { percent: -5, resetsAt: "2026-05-02T12:00:00Z" },
                monthly: { percent: "42", resetsAt: "2026-06-01T12:00:00Z" }
            }
        }, testCase.nowMs)

        compare(result.ok, true)
        compare(result.windows[0].usedPercent, 100)
        compare(result.windows[1].usedPercent, 0)
        compare(result.windows[2].usedPercent, 42)
        compare(UsageApi.clampPercent(Infinity), 0)
        compare(UsageApi.clampPercent("not a number"), 0)
    }

    function test_missingAndMalformedFieldsUseSafeDefaults() {
        const result = UsageApi.normalizeResponse({
            usage: {
                rolling: { percent: "oops", resetsAt: "not a date" }
            }
        }, testCase.nowMs)

        compare(result.ok, true)
        compare(result.windows.length, 3)
        compare(result.windows[0].usedPercent, 0)
        compare(result.windows[0].resetsAt, 0)
        compare(result.windows[0].resetsInSeconds, 0)
        compare(result.windows[1].label, "Weekly")
        compare(result.windows[2].usedPercent, 0)
    }

    function test_pastResetTimestampClampsCountdownToZero() {
        const result = UsageApi.normalizeEntry({
            usedPercent: 10,
            resetsAt: "2026-05-01T11:00:00Z"
        }, testCase.nowMs)

        compare(result.resetsAt, Date.parse("2026-05-01T11:00:00Z"))
        compare(result.resetsInSeconds, 0)
    }

    function test_badPayloadsAreRejected() {
        compare(UsageApi.normalizeResponse("not json", testCase.nowMs).ok, false)
        compare(UsageApi.normalizeResponse({}, testCase.nowMs).ok, false)
        compare(UsageApi.normalizeResponse([], testCase.nowMs).ok, false)
        compare(UsageApi.normalizeResponse(null, testCase.nowMs).ok, false)
        compare(UsageApi.normalizeResponse({ usage: [] }, testCase.nowMs).ok, false)
    }

    function test_errorMessagesAreConciseAndStatusSpecific() {
        verify(UsageApi.errorForStatus(0).indexOf("network") >= 0)
        verify(UsageApi.errorForStatus(401).indexOf("key rejected") >= 0)
        verify(UsageApi.errorForStatus(403).indexOf("key rejected") >= 0)
        verify(UsageApi.errorForStatus(404).indexOf("not found") >= 0)
        verify(UsageApi.errorForStatus(408).indexOf("timed out") >= 0)
        verify(UsageApi.errorForStatus(429).indexOf("Too many") >= 0)
        verify(UsageApi.errorForStatus(500).indexOf("Server error") >= 0)
        verify(UsageApi.errorForStatus(418).indexOf("HTTP 418") >= 0)
    }

    function test_apiKeyDetection() {
        compare(UsageApi.hasApiKey(""), false)
        compare(UsageApi.hasApiKey("   "), false)
        compare(UsageApi.hasApiKey("\n\t"), false)
        compare(UsageApi.hasApiKey(undefined), false)
        compare(UsageApi.hasApiKey("test-key-not-real"), true)
    }

    function test_sampleDataUsesDocumentedValues() {
        const sample = UsageApi.sampleWindows(testCase.nowMs)

        compare(sample.length, 3)
        compare(sample[0].usedPercent, 10)
        compare(sample[0].resetsInSeconds, 14820)
        compare(sample[1].usedPercent, 4)
        compare(sample[1].resetsInSeconds, 133200)
        compare(sample[2].usedPercent, 2)
        compare(sample[2].resetsInSeconds, 2588400)
    }
}
