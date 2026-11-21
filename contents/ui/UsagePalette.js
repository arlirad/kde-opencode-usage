.pragma library

const TARGET_CONTRAST = 3.0
const MIN_TRACK_ALPHA = 0.12
const MAX_TRACK_ALPHA = 0.85
const ALPHA_STEP = 0.01
const MIX_STEP = 0.02

function linear(channel) {
    return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
}

function luminance(color) {
    return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
}

function contrast(first, second) {
    const lighter = Math.max(luminance(first), luminance(second))
    const darker = Math.min(luminance(first), luminance(second))
    return (lighter + 0.05) / (darker + 0.05)
}

function mix(start, end, amount) {
    return Qt.rgba(
        start.r + (end.r - start.r) * amount,
        start.g + (end.g - start.g) * amount,
        start.b + (end.b - start.b) * amount,
        1)
}

function trackColor(background, foreground) {
    let track = foreground

    for (let alpha = MIN_TRACK_ALPHA; alpha <= MAX_TRACK_ALPHA; alpha += ALPHA_STEP) {
        track = mix(background, foreground, alpha)
        if (contrast(track, background) >= TARGET_CONTRAST) {
            return track
        }
    }

    return track
}

function readableAccent(accent, track, fallback) {
    if (contrast(accent, track) >= TARGET_CONTRAST) {
        return accent
    }

    const black = Qt.rgba(0, 0, 0, 1)
    const white = Qt.rgba(1, 1, 1, 1)

    for (let amount = MIX_STEP; amount <= 1; amount += MIX_STEP) {
        const darker = mix(accent, black, amount)
        if (contrast(darker, track) >= TARGET_CONTRAST) {
            return darker
        }

        const lighter = mix(accent, white, amount)
        if (contrast(lighter, track) >= TARGET_CONTRAST) {
            return lighter
        }
    }

    return fallback
}
