import QtQuick

QtObject {
    id: provider

    readonly property bool isSampleData: true

    readonly property ListModel windows: ListModel {
        ListElement {
            windowId: "five_hour"
            label: "5-hour window"
            usedPercent: 10
            resetsInSeconds: 14820
        }
        ListElement {
            windowId: "weekly"
            label: "Weekly"
            usedPercent: 4
            resetsInSeconds: 133200
        }
        ListElement {
            windowId: "monthly"
            label: "Monthly"
            usedPercent: 2
            resetsInSeconds: 2588400
        }
    }

    function usageRatio(usedPercent) {
        return Math.max(0, Math.min(1, Number(usedPercent) / 100))
    }

    function formatPercent(usedPercent) {
        const clamped = Math.max(0, Math.min(100, Number(usedPercent)))
        return Math.round(clamped) + "%"
    }

    function formatUsagePercent(usedPercent) {
        return formatPercent(usedPercent) + " used"
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

    function highestUsageIndex() {
        let highest = -1
        let index = -1

        for (let i = 0; i < windows.count; ++i) {
            const value = windows.get(i).usedPercent
            if (value > highest) {
                highest = value
                index = i
            }
        }

        return index
    }

    function summaryText() {
        const parts = []

        for (let i = 0; i < windows.count; ++i) {
            const item = windows.get(i)
            parts.push(item.label + ": " + formatUsagePercent(item.usedPercent) + ", " + formatReset(item.resetsInSeconds))
        }

        return parts.join(". ")
    }

    function applyUsage(entries) {
        windows.clear()

        for (let i = 0; i < entries.length; ++i) {
            const entry = entries[i]
            windows.append({
                "windowId": entry.windowId !== undefined ? String(entry.windowId) : String(i),
                "label": entry.label !== undefined ? String(entry.label) : "",
                "usedPercent": entry.usedPercent !== undefined ? Number(entry.usedPercent) : 0,
                "resetsInSeconds": entry.resetsInSeconds !== undefined ? Number(entry.resetsInSeconds) : 0
            })
        }
    }
}
