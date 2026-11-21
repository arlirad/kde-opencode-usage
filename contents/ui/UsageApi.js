.pragma library

var endpoint = "https://opencode.ai/zen/go/v1/usage"
var requestTimeoutMs = 15000

var WINDOW_DEFINITIONS = [
    { windowId: "five_hour", label: "5-hour window", responseKey: "rolling" },
    { windowId: "weekly", label: "Weekly", responseKey: "weekly" },
    { windowId: "monthly", label: "Monthly", responseKey: "monthly" }
]

function windowDefinitions() {
    return WINDOW_DEFINITIONS.map(function (definition) {
        return {
            windowId: definition.windowId,
            label: definition.label,
            responseKey: definition.responseKey
        }
    })
}

function defaultEntries(nowMs) {
    var now = nowMs === undefined ? Date.now() : Number(nowMs)
    return windowDefinitions().map(function (definition) {
        return normalizeEntry({
            windowId: definition.windowId,
            label: definition.label
        }, now)
    })
}

function hasApiKey(value) {
    return typeof value === "string" && value.trim().length > 0
}

function clampPercent(value) {
    var percent = Number(value)
    if (!isFinite(percent)) {
        return 0
    }
    return Math.max(0, Math.min(100, percent))
}

function normalizeEpoch(value) {
    var epoch = Number(value)
    if (!isFinite(epoch) || epoch <= 0) {
        return 0
    }
    return epoch > 100000000000 ? epoch : epoch * 1000
}

function parseTimestamp(value) {
    if (typeof value === "number") {
        return normalizeEpoch(value)
    }

    if (typeof value === "string") {
        var trimmed = value.trim()
        if (trimmed.length === 0) {
            return 0
        }

        var numeric = Number(trimmed)
        if (isFinite(numeric)) {
            return normalizeEpoch(numeric)
        }

        var parsed = Date.parse(trimmed)
        return isFinite(parsed) ? parsed : 0
    }

    return 0
}

function remainingSeconds(resetsAt, nowMs) {
    if (!resetsAt) {
        return 0
    }
    return Math.max(0, Math.round((Number(resetsAt) - Number(nowMs)) / 1000))
}

function normalizeEntry(entry, nowMs) {
    var now = nowMs === undefined ? Date.now() : Number(nowMs)
    var source = entry !== null && typeof entry === "object" ? entry : {}
    var resetsAt = 0

    if (source.resetsAt !== undefined && source.resetsAt !== null && source.resetsAt !== "") {
        resetsAt = parseTimestamp(source.resetsAt)
    } else if (source.resetsInSeconds !== undefined) {
        var seconds = Number(source.resetsInSeconds)
        if (isFinite(seconds) && seconds >= 0) {
            resetsAt = now + seconds * 1000
        }
    }

    return {
        windowId: source.windowId !== undefined ? String(source.windowId) : "",
        label: source.label !== undefined ? String(source.label) : "",
        usedPercent: clampPercent(source.usedPercent !== undefined ? source.usedPercent : source.percent),
        resetsAt: resetsAt,
        resetsInSeconds: remainingSeconds(resetsAt, now)
    }
}

function normalizeResponse(body, nowMs) {
    var now = nowMs === undefined ? Date.now() : Number(nowMs)
    var payload = body

    if (typeof body === "string") {
        try {
            payload = JSON.parse(body)
        } catch (error) {
            return {
                ok: false,
                error: "Invalid JSON response from server.",
                windows: []
            }
        }
    }

    if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
        return {
            ok: false,
            error: "Unexpected response from server.",
            windows: []
        }
    }

    var usage = payload.usage
    if (usage === null || typeof usage !== "object" || Array.isArray(usage)) {
        return {
            ok: false,
            error: "Unexpected response from server.",
            windows: []
        }
    }

    var windows = windowDefinitions().map(function (definition) {
        var normalized = normalizeEntry(usage[definition.responseKey], now)
        normalized.windowId = definition.windowId
        normalized.label = definition.label
        return normalized
    })

    return {
        ok: true,
        error: "",
        windows: windows
    }
}

function errorForStatus(status) {
    var code = Number(status)
    if (!isFinite(code)) {
        code = 0
    }

    if (code === 0) {
        return "Can't reach OpenCode. Check your network connection."
    }
    if (code === 401 || code === 403) {
        return "API key rejected. Check the key in widget settings."
    }
    if (code === 404) {
        return "Usage endpoint not found."
    }
    if (code === 408) {
        return "Request timed out."
    }
    if (code === 429) {
        return "Too many requests. Try again later."
    }
    if (code >= 500) {
        return "Server error (HTTP " + code + "). Try again later."
    }
    return "Request failed (HTTP " + code + ")."
}
