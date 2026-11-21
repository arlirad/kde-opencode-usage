import QtQuick
import "UsageApi.js" as UsageApi

QtObject {
    id: provider

    property string apiKey: ""
    property int pollIntervalMinutes: 5
    property bool demoMode: false
    property UsageClient client: UsageClient {}
    property double nowMs: Date.now()
    property string errorText: ""
    property double lastUpdatedMs: 0
    property int revision: 0

    readonly property bool hasKey: UsageApi.hasApiKey(provider.apiKey)
    readonly property bool loading: provider._loading
    readonly property bool hasData: provider._hasData
    readonly property bool isSampleData: provider.state === "demo"

    readonly property string state: {
        const configured = UsageApi.hasApiKey(provider.apiKey)

        if (provider.demoMode && !configured) {
            return "demo"
        }
        if (!configured) {
            return "setup"
        }
        if (provider._loading) {
            return "loading"
        }
        if (provider.errorText.length > 0) {
            return "error"
        }
        if (provider.hasData) {
            return "ready"
        }
        return "loading"
    }

    readonly property ListModel windows: ListModel {}

    property bool _loading: false
    property bool _hasData: false

    onApiKeyChanged: {
        provider.client.abort()
        provider._loading = false
        provider.errorText = ""
        provider.resetWindows()
        if (!UsageApi.hasApiKey(provider.apiKey) && provider.demoMode) {
            provider.applySampleData()
        }
    }

    onDemoModeChanged: {
        provider.client.abort()
        provider._loading = false
        provider.errorText = ""
        if (!UsageApi.hasApiKey(provider.apiKey)) {
            provider.resetWindows()
            if (provider.demoMode) {
                provider.applySampleData()
            }
        }
    }

    Component.onCompleted: {
        provider.resetWindows()
        if (provider.demoMode && !UsageApi.hasApiKey(provider.apiKey)) {
            provider.applySampleData()
        }
    }

    function refresh() {
        if (!UsageApi.hasApiKey(provider.apiKey)) {
            return
        }
        if (provider.client.busy) {
            return
        }

        provider.errorText = ""
        provider._loading = true
        provider.client.fetch(provider.apiKey)
    }

    function applyResponse(status, body, responseTimeMs) {
        provider._loading = false

        const time = responseTimeMs === undefined ? Date.now() : Number(responseTimeMs)
        if (Number(status) === 200) {
            const result = UsageApi.normalizeResponse(body, time)
            if (!result.ok) {
                provider.errorText = result.error
                return
            }

            provider.applyUsage(result.windows, time)
            provider.errorText = ""
            return
        }

        provider.errorText = UsageApi.errorForStatus(status)
    }

    function handleFailure(message) {
        provider._loading = false
        provider.errorText = String(message)
    }

    function applyUsage(entries, responseTimeMs) {
        const time = responseTimeMs === undefined ? Date.now() : Number(responseTimeMs)
        provider._replaceWindows(entries, time)
        provider._hasData = entries.length > 0
        provider.lastUpdatedMs = time
    }

    function resetWindows() {
        provider._replaceWindows(UsageApi.defaultEntries(provider.nowMs), provider.nowMs)
        provider._hasData = false
        provider.lastUpdatedMs = 0
    }

    function applySampleData() {
        provider.applyUsage(UsageApi.sampleWindows(provider.nowMs), provider.nowMs)
    }

    function _replaceWindows(entries, time) {
        provider.windows.clear()

        for (let index = 0; index < entries.length; ++index) {
            const entry = UsageApi.normalizeEntry(entries[index], time)
            provider.windows.append({
                "windowId": entry.windowId.length > 0 ? entry.windowId : String(index),
                "label": entry.label,
                "usedPercent": entry.usedPercent,
                "resetsAt": entry.resetsAt,
                "resetsInSeconds": entry.resetsInSeconds
            })
        }

        provider.revision += 1
    }

    function usageRatio(usedPercent) {
        return Math.max(0, Math.min(1, Number(usedPercent) / 100))
    }

    function formatPercent(usedPercent) {
        const clamped = Math.max(0, Math.min(100, Number(usedPercent)))
        return Math.round(clamped) + "%"
    }

    function formatUsagePercent(usedPercent) {
        return provider.formatPercent(usedPercent) + " used"
    }

    function formatUsagePercentOrPlaceholder(usedPercent) {
        return provider.hasData ? provider.formatUsagePercent(usedPercent) : "—"
    }

    function formatReset(resetsInSeconds) {
        const totalMinutes = Math.floor(Math.max(0, Number(resetsInSeconds)) / 60)
        if (totalMinutes < 1) {
            return "Resets in <1m"
        }

        const days = Math.floor(totalMinutes / 1440)
        const hours = Math.floor((totalMinutes % 1440) / 60)
        const minutes = totalMinutes % 60
        const parts = []

        if (days > 0) {
            parts.push(days + "d")
        }
        if (hours > 0) {
            parts.push(hours + "h")
        }
        if (minutes > 0) {
            parts.push(minutes + "m")
        }

        return "Resets in " + parts.join(" ")
    }

    function formatResetAt(resetsAt) {
        if (!resetsAt) {
            return "—"
        }
        return provider.formatReset(UsageApi.remainingSeconds(resetsAt, provider.nowMs))
    }

    function highestUsageIndex() {
        let highest = -1
        let index = -1

        for (let i = 0; i < provider.windows.count; ++i) {
            const value = provider.windows.get(i).usedPercent
            if (value > highest) {
                highest = value
                index = i
            }
        }

        return index
    }

    function summaryText() {
        const state = provider.state
        const revision = provider.revision

        if (state === "setup") {
            return "OpenCode Go API key not configured. Open widget settings."
        }
        if (state === "demo") {
            return "Sample data. " + provider._rowsSummary()
        }
        if (state === "error") {
            return provider.hasData
                ? "Update failed: " + provider.errorText + " Showing last known values."
                : "Update failed: " + provider.errorText
        }
        if (state === "loading") {
            return provider.hasData
                ? "Updating usage… " + provider._rowsSummary()
                : "Loading usage…"
        }
        return provider._rowsSummary()
    }

    function _rowsSummary() {
        const parts = []

        for (let i = 0; i < provider.windows.count; ++i) {
            const item = provider.windows.get(i)
            const reset = item.resetsAt > 0 ? provider.formatResetAt(item.resetsAt) : "reset time unavailable"
            parts.push(item.label + ": " + provider.formatUsagePercent(item.usedPercent) + ", " + reset)
        }

        return parts.join(". ")
    }

    readonly property Timer clockTimer: Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: provider.nowMs = Date.now()
    }

    readonly property Timer pollTimer: Timer {
        interval: Math.max(1, provider.pollIntervalMinutes) * 60000
        repeat: true
        running: UsageApi.hasApiKey(provider.apiKey)
        onTriggered: provider.refresh()
    }

    readonly property Connections clientConnections: Connections {
        target: provider.client

        function onFinished(status, body) {
            provider.applyResponse(status, body)
        }

        function onFailed(message) {
            provider.handleFailure(message)
        }
    }
}
