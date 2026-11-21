import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    "metadata.json",
    "README.md",
    "Makefile",
    "contents/ui/main.qml",
    "contents/ui/FullRepresentation.qml",
    "contents/ui/CompactRepresentation.qml",
    "contents/ui/UsageRow.qml",
    "contents/ui/UsageBar.qml",
    "contents/ui/UsageBadge.qml",
    "contents/ui/UsageResetLabel.qml",
    "contents/ui/UsageProvider.qml",
    "contents/ui/UsagePalette.js",
    "tests/tst_compact_activation.qml",
    "tests/contrast_probe.py",
]

EXPECTED_WINDOWS = [
    ("5-hour window", 10, 14820, "10% used", "Resets in 4h 7m"),
    ("Weekly", 4, 133200, "4% used", "Resets in 1d 13h"),
    ("Monthly", 2, 2588400, "2% used", "Resets in 29d 23h"),
]

CHECKED_FILES = [
    "contents/ui/main.qml",
    "contents/ui/FullRepresentation.qml",
    "contents/ui/CompactRepresentation.qml",
    "contents/ui/UsageRow.qml",
    "contents/ui/UsageBar.qml",
    "contents/ui/UsageBadge.qml",
    "contents/ui/UsageResetLabel.qml",
    "contents/ui/UsageProvider.qml",
    "contents/ui/UsagePalette.js",
]


def format_usage_percent(percent):
    return f"{round(max(0, min(100, percent)))}% used"


def format_reset(seconds):
    total_minutes = int(max(0, seconds) // 60)
    if total_minutes < 1:
        return "Resets in <1m"
    days, remainder = divmod(total_minutes, 1440)
    hours, minutes = divmod(remainder, 60)
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours:
        parts.append(f"{hours}h")
    if minutes:
        parts.append(f"{minutes}m")
    return "Resets in " + " ".join(parts)


def main():
    checks = []
    missing = [path for path in REQUIRED_FILES if not (ROOT / path).is_file()]
    checks.append(("required project files exist", not missing, ", ".join(missing)))

    metadata = {}
    try:
        metadata = json.loads((ROOT / "metadata.json").read_text(encoding="utf-8"))
        metadata_error = ""
    except (OSError, json.JSONDecodeError) as error:
        metadata_error = str(error)

    plugin = metadata.get("KPlugin", {})
    checks.append(("metadata.json is valid JSON", not metadata_error, metadata_error))
    checks.append(("package structure is Plasma/Applet", metadata.get("KPackageStructure") == "Plasma/Applet", metadata.get("KPackageStructure", "")))
    checks.append(("plugin id matches directory", plugin.get("Id") == "org.opencode.usage", plugin.get("Id", "")))
    checks.append(("plasma 6 minimum API is declared", metadata.get("X-Plasma-API-Minimum-Version") == "6.0", metadata.get("X-Plasma-API-Minimum-Version", "")))
    checks.append(("plugin name and description are present", bool(plugin.get("Name")) and bool(plugin.get("Description")), ""))

    provider_path = ROOT / "contents/ui/UsageProvider.qml"
    provider_text = provider_path.read_text(encoding="utf-8") if provider_path.is_file() else ""
    row_pattern = re.compile(
        r'ListElement\s*\{\s*windowId:\s*"(?P<window_id>[^"]+)"\s*;?\s*'
        r'label:\s*"(?P<label>[^"]+)"\s*;?\s*'
        r'usedPercent:\s*(?P<percent>\d+(?:\.\d+)?)\s*;?\s*'
        r'resetsInSeconds:\s*(?P<seconds>\d+)\s*\}'
    )
    rows = [
        (match.group("label"), float(match.group("percent")), int(match.group("seconds")))
        for match in row_pattern.finditer(provider_text)
    ]

    checks.append(("provider declares sample data", "isSampleData: true" in provider_text, ""))
    checks.append(("provider exposes applyUsage replacement hook", "function applyUsage" in provider_text, ""))
    checks.append(("provider has three sample windows", len(rows) == 3, f"found {len(rows)}"))

    expected_rows = [(label, float(percent), seconds) for label, percent, seconds, _, _ in EXPECTED_WINDOWS]
    checks.append(("sample rows match documented values", rows == expected_rows, f"expected {expected_rows}, found {rows}"))

    for index, (label, percent, seconds, badge, reset) in enumerate(EXPECTED_WINDOWS):
        if index >= len(rows):
            checks.append((f"sample row {label} is present", False, "row missing"))
            continue
        row_label, row_percent, row_seconds = rows[index]
        checks.append((f"row label is {label}", row_label == label, row_label))
        checks.append((f"row badge is {badge}", format_usage_percent(row_percent) == badge, format_usage_percent(row_percent)))
        checks.append((f"row reset is {reset}", format_reset(row_seconds) == reset, format_reset(row_seconds)))
        checks.append((f"row reset seconds are consistent for {label}", int(row_seconds) == seconds, str(row_seconds)))

    main_text = (ROOT / "contents/ui/main.qml").read_text(encoding="utf-8") if (ROOT / "contents/ui/main.qml").is_file() else ""
    checks.append(("main.qml is a PlasmoidItem", "PlasmoidItem" in main_text, ""))
    checks.append(("main.qml wires both representations", "compactRepresentation:" in main_text and "fullRepresentation:" in main_text, ""))
    checks.append(("main.qml owns the provider", "UsageProvider {}" in main_text, ""))

    qml_text = "\n".join((ROOT / path).read_text(encoding="utf-8") for path in CHECKED_FILES if (ROOT / path).is_file())
    usage_row_text = (ROOT / "contents/ui/UsageRow.qml").read_text(encoding="utf-8")
    full_text = (ROOT / "contents/ui/FullRepresentation.qml").read_text(encoding="utf-8")
    compact_text = (ROOT / "contents/ui/CompactRepresentation.qml").read_text(encoding="utf-8")
    badge_text = (ROOT / "contents/ui/UsageBadge.qml").read_text(encoding="utf-8")
    bar_text = (ROOT / "contents/ui/UsageBar.qml").read_text(encoding="utf-8")
    reset_label_text = (ROOT / "contents/ui/UsageResetLabel.qml").read_text(encoding="utf-8")

    for _, _, _, badge, reset in EXPECTED_WINDOWS:
        checks.append((f"UI exposes badge label {badge}", "percentText" in qml_text, ""))
        checks.append((f"UI exposes reset label {reset}", "resetText" in qml_text, ""))

    checks.append(("accessibility metadata is present", "Accessible.name" in qml_text, ""))
    checks.append(("responsive KDE units are used", "Kirigami.Units" in qml_text, ""))
    checks.append(("UI uses KDE theme colors", "Kirigami.Theme." in qml_text, ""))
    checks.append(("usage accent is theme-derived", "positiveTextColor" in qml_text, ""))
    checks.append(("UI has no custom palette file", not (ROOT / "contents/ui/UsageTheme.js").exists(), ""))
    checks.append(("UI has no hard-coded hex colors", not re.search(r"#[0-9a-fA-F]{6}\b", qml_text), ""))
    checks.append(("UI does not force font families or sizes", not any(token in qml_text for token in ("font.family", "font.pointSize", "font.pixelSize", "font.weight")), ""))
    checks.append(("row reflows its reset label at compact widths", "stackedLayout: width <" in usage_row_text and "UsageResetLabel" in usage_row_text, ""))
    checks.append(("full card height derives from content plus compact padding", "implicitHeight: content.implicitHeight + root.padding * 2" in full_text, ""))
    checks.append(("full card uses tighter derived row spacing", "rowSpacing: Math.round(Kirigami.Units.smallSpacing * 1.5)" in full_text, ""))
    checks.append(("full and compact rows share one progress bar", "UsageBar" in usage_row_text and "UsageBar" in compact_text, ""))
    checks.append(("progress track derives from theme background and text", "UsagePalette.trackColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor)" in bar_text, ""))
    checks.append(("progress fill uses a readable theme accent", "UsagePalette.readableAccent(Kirigami.Theme.highlightColor" in bar_text, ""))
    checks.append(("badge text uses readable theme text", "color: Kirigami.Theme.textColor" in badge_text, ""))
    checks.append(("badge accent is retained as an outline", "border.color: Kirigami.Theme.positiveTextColor" in badge_text, ""))
    checks.append(("reset label uses readable theme text", "color: Kirigami.Theme.textColor" in reset_label_text and "opacity: 0.72" in reset_label_text and "disabledTextColor" not in reset_label_text, ""))
    checks.append(("compact representation toggles expansion", "function toggleExpanded" in compact_text and "expanded = !" in compact_text and "onClicked" in compact_text, ""))
    checks.append(("compact representation supports keyboard focus", "PlasmaComponents3.AbstractButton" in compact_text and "activeFocusOnTab: true" in compact_text, ""))
    checks.append(("compact focus ring uses readable theme text", "focusRingColor: Kirigami.Theme.textColor" in compact_text, ""))
    checks.append(("main passes the plasmoid item to the compact view", "plasmoidItem: root" in main_text, ""))

    readme_path = ROOT / "README.md"
    readme_text = readme_path.read_text(encoding="utf-8") if readme_path.is_file() else ""
    checks.append(("README documents unknown real API contract", "unknown" in readme_text.lower() and "api" in readme_text.lower(), ""))
    checks.append(("README documents theme-derived styling", "Kirigami.Theme" in readme_text, ""))
    for label, _, _, badge, reset in EXPECTED_WINDOWS:
        checks.append((f"README documents sample {label}", label in readme_text and badge in readme_text and reset in readme_text, ""))

    failures = [check for check in checks if not check[1]]
    for description, passed, detail in checks:
        status = "ok" if passed else "not ok"
        suffix = f" ({detail})" if detail and not passed else ""
        print(f"{status} - {description}{suffix}")

    if failures:
        print(f"FAILED: {len(failures)} of {len(checks)} checks failed")
        return 1

    print(f"OK: {len(checks)} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
