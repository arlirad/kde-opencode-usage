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
    return {
        "background": tuple(int(value) for value in section["BackgroundNormal"].split(",")),
        "text": tuple(int(value) for value in section["ForegroundNormal"].split(",")),
        "positive": tuple(int(value) for value in section["ForegroundPositive"].split(",")),
        "focus": tuple(int(value) for value in section["DecorationFocus"].split(",")),
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
    return tuple(round(background[index] + alpha * (foreground[index] - background[index])) for index in range(3))


def progress_colors():
    source = (ROOT / "contents/ui/UsageBar.qml").read_text(encoding="utf-8")
    match = re.search(r"Kirigami\.Theme\.textColor\.b,\s*([0-9]*\.?[0-9]+)\)", source)
    if match is None:
        raise ValueError("track alpha is not defined as a textColor-based Qt.rgba color")
    if "color: Kirigami.Theme.textColor" not in source:
        raise ValueError("progress fill is not defined from theme text color")
    return float(match.group(1))


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
    alpha = progress_colors()
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
        track_color = blend(colors["background"], colors["text"], alpha)
        track_ratio = contrast(colors["background"], track_color)
        fill_ratio = contrast(track_color, colors["text"])
        accent_ratio = contrast(colors["background"], colors["positive"])
        focus_ratio = contrast(colors["background"], colors[focus_key])

        print(
            f"{theme}: badge text {badge_ratio:.2f}:1 (AA >= {AA_TEXT}), "
            f"track-vs-bg {track_ratio:.2f}:1 (non-text >= {AA_NON_TEXT}), "
            f"fill-vs-track {fill_ratio:.2f}:1 (non-text >= {AA_NON_TEXT}), "
            f"focus ring {focus_ratio:.2f}:1 (non-text >= {AA_NON_TEXT}), "
            f"accent outline {accent_ratio:.2f}:1"
        )
        if badge_ratio < AA_TEXT:
            failures.append(f"{theme}: badge text contrast {badge_ratio:.2f}:1")
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

    print(f"OK: contrast checks passed for {available} theme(s) at track alpha {alpha:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
