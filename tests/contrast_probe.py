import configparser
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEMES = {
    "BreezeLight": "BreezeLight.colors",
    "BreezeDark": "BreezeDark.colors",
}
AA_TEXT = 4.5
AA_NON_TEXT = 3.0


def scheme_directories():
    directories = [
        Path(path) / "color-schemes"
        for path in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
        if path
    ]
    directories.append(Path.home() / ".local/share/color-schemes")
    return directories


def find_scheme(name):
    for directory in scheme_directories():
        candidate = directory / name
        if candidate.is_file():
            return candidate
    return None


def read_colors(path):
    parser = configparser.ConfigParser()
    parser.read(path, encoding="utf-8")
    section = parser["Colors:Window"]
    selection = parser["Colors:Selection"]
    return {
        "background": tuple(int(value) for value in section["BackgroundNormal"].split(",")),
        "text": tuple(int(value) for value in section["ForegroundNormal"].split(",")),
        "positive": tuple(int(value) for value in section["ForegroundPositive"].split(",")),
        "focus": tuple(int(value) for value in section["DecorationFocus"].split(",")),
        "highlight": tuple(int(value) for value in selection["BackgroundNormal"].split(",")),
    }


def linear(channel):
    value = channel / 255
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def luminance(color):
    red, green, blue = (linear(channel) for channel in color)
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def contrast(first, second):
    lighter = max(luminance(first), luminance(second))
    darker = min(luminance(first), luminance(second))
    return (lighter + 0.05) / (darker + 0.05)


def blend(background, foreground, alpha):
    return tuple(background[index] + alpha * (foreground[index] - background[index]) for index in range(3))


def palette_parameters():
    source = (ROOT / "contents/ui/UsagePalette.js").read_text(encoding="utf-8")
    bar = (ROOT / "contents/ui/UsageBar.qml").read_text(encoding="utf-8")
    if "UsagePalette.trackColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor)" not in bar:
        raise ValueError("track is not derived from theme background and text colors")
    if "UsagePalette.readableAccent(Kirigami.Theme.highlightColor" not in bar:
        raise ValueError("fill is not derived from the theme highlight color")
    values = {}
    for name in ("TARGET_CONTRAST", "MIN_TRACK_ALPHA", "MAX_TRACK_ALPHA", "ALPHA_STEP", "MIX_STEP"):
        match = re.search(rf"{name}\s*=\s*([0-9]*\.?[0-9]+)", source)
        if match is None:
            raise ValueError(f"palette constant {name} is not defined")
        values[name] = float(match.group(1))
    return values


def track_color(background, foreground, parameters):
    track = foreground
    alpha = parameters["MIN_TRACK_ALPHA"]
    while alpha <= parameters["MAX_TRACK_ALPHA"]:
        track = blend(background, foreground, alpha)
        if contrast(track, background) >= parameters["TARGET_CONTRAST"]:
            return track
        alpha += parameters["ALPHA_STEP"]
    return track


def readable_accent(accent, track, fallback, parameters):
    if contrast(accent, track) >= parameters["TARGET_CONTRAST"]:
        return accent
    black = (0, 0, 0)
    white = (255, 255, 255)
    amount = parameters["MIX_STEP"]
    while amount <= 1:
        darker = blend(accent, black, amount)
        if contrast(darker, track) >= parameters["TARGET_CONTRAST"]:
            return darker
        lighter = blend(accent, white, amount)
        if contrast(lighter, track) >= parameters["TARGET_CONTRAST"]:
            return lighter
        amount += parameters["MIX_STEP"]
    return fallback


def focus_ring_color():
    source = (ROOT / "contents/ui/CompactRepresentation.qml").read_text(encoding="utf-8")
    match = re.search(r"focusRingColor:\s*Kirigami\.Theme\.(\w+)", source)
    if match is None:
        raise ValueError("focus ring color is not defined as a Kirigami theme color")
    names = {"textColor": "text", "focusColor": "focus"}
    if match.group(1) not in names:
        raise ValueError(f"unsupported focus ring color: {match.group(1)}")
    return names[match.group(1)]


def main():
    parameters = palette_parameters()
    focus_key = focus_ring_color()
    failures = []
    available = 0

    for theme, filename in SCHEMES.items():
        path = find_scheme(filename)
        if path is None:
            continue
        available += 1
        colors = read_colors(path)
        badge_ratio = contrast(colors["background"], colors["text"])
        track = track_color(colors["background"], colors["text"], parameters)
        track_ratio = contrast(colors["background"], track)
        fill = readable_accent(colors["highlight"], track, colors["text"], parameters)
        fill_ratio = contrast(track, fill)
        reset_ratio = contrast(colors["background"], blend(colors["background"], colors["text"], 0.72))
        accent_ratio = contrast(colors["background"], colors["positive"])
        focus_ratio = contrast(colors["background"], colors[focus_key])

        print(
            f"{theme}: badge text {badge_ratio:.2f}:1 (AA >= {AA_TEXT}), "
            f"reset text {reset_ratio:.2f}:1 (AA >= {AA_TEXT}), "
            f"track-vs-bg {track_ratio:.2f}:1 (non-text >= {AA_NON_TEXT}), "
            f"fill-vs-track {fill_ratio:.2f}:1 (non-text >= {AA_NON_TEXT}), "
            f"focus ring {focus_ratio:.2f}:1 (non-text >= {AA_NON_TEXT}), "
            f"accent outline {accent_ratio:.2f}:1"
        )
        if badge_ratio < AA_TEXT:
            failures.append(f"{theme}: badge text contrast {badge_ratio:.2f}:1")
        if reset_ratio < AA_TEXT:
            failures.append(f"{theme}: reset text contrast {reset_ratio:.2f}:1")
        if track_ratio < AA_NON_TEXT:
            failures.append(f"{theme}: track contrast {track_ratio:.2f}:1")
        if fill_ratio < AA_NON_TEXT:
            failures.append(f"{theme}: fill contrast {fill_ratio:.2f}:1")
        if focus_ratio < AA_NON_TEXT:
            failures.append(f"{theme}: focus ring contrast {focus_ratio:.2f}:1")

    if available == 0:
        print("SKIP: Breeze color schemes not found")
        return 0

    if failures:
        for failure in failures:
            print(f"not ok - {failure}")
        print(f"FAILED: {len(failures)} contrast checks failed")
        return 1

    print(f"OK: contrast checks passed for {available} theme(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
