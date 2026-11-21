import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    "metadata.json",
    "README.md",
    "Makefile",
    "contents/config/config.qml",
    "contents/config/main.xml",
    "contents/ui/main.qml",
    "contents/ui/FullRepresentation.qml",
    "contents/ui/CompactRepresentation.qml",
    "contents/ui/UsageRow.qml",
    "contents/ui/UsageProvider.qml",
    "contents/ui/UsageClient.qml",
    "contents/ui/UsageApi.js",
    "contents/ui/configGeneral.qml",
    "tests/tst_compact_activation.qml",
    "tests/tst_usage_api.qml",
    "tests/tst_usage_provider.qml",
]

CHECKED_FILES = [
    "contents/ui/main.qml",
    "contents/ui/FullRepresentation.qml",
    "contents/ui/CompactRepresentation.qml",
    "contents/ui/UsageRow.qml",
    "contents/ui/UsageProvider.qml",
    "contents/ui/UsageClient.qml",
    "contents/ui/configGeneral.qml",
]

EXPECTED_WINDOW_ORDER = ["five_hour", "weekly", "monthly"]
EXPECTED_LABELS = ["5-hour window", "Weekly", "Monthly"]
ENDPOINT = "https://opencode.ai/zen/go/v1/usage"
SAMPLE_VALUES = [(10, 14820), (4, 133200), (2, 2588400)]


def read(path):
    file_path = ROOT / path
    return file_path.read_text(encoding="utf-8") if file_path.is_file() else ""


def main():
    checks = []
    texts = {path: read(path) for path in REQUIRED_FILES}
    checked_qml = "\n".join(read(path) for path in CHECKED_FILES)
    all_sources = checked_qml + "\n" + "\n".join(read(path) for path in REQUIRED_FILES if path.endswith(".js"))

    missing = [path for path in REQUIRED_FILES if not (ROOT / path).is_file()]
    checks.append(("required project files exist", not missing, ", ".join(missing)))

    removed = [
        "contents/ui/UsagePalette.js",
        "contents/ui/UsageBar.qml",
        "contents/ui/UsageBadge.qml",
        "contents/ui/UsageResetLabel.qml",
        "tests/contrast_probe.py",
    ]
    leftover = [path for path in removed if (ROOT / path).exists()]
    checks.append(("obsolete custom-style files are gone", not leftover, ", ".join(leftover)))

    try:
        metadata = json.loads(texts["metadata.json"])
        metadata_error = ""
    except json.JSONDecodeError as error:
        metadata = {}
        metadata_error = str(error)

    plugin = metadata.get("KPlugin", {})
    checks.append(("metadata.json is valid JSON", not metadata_error, metadata_error))
    checks.append(("package structure is Plasma/Applet", metadata.get("KPackageStructure") == "Plasma/Applet", metadata.get("KPackageStructure", "")))
    checks.append(("plugin id is unchanged", plugin.get("Id") == "org.opencode.usage", plugin.get("Id", "")))
    checks.append(("plugin name is unchanged", plugin.get("Name") == "OpenCode Usage", plugin.get("Name", "")))
    checks.append(("plasma 6 minimum API is declared", metadata.get("X-Plasma-API-Minimum-Version") == "6.0", metadata.get("X-Plasma-API-Minimum-Version", "")))
    checks.append(("plugin description is present", bool(plugin.get("Description")), ""))

    api_text = texts["contents/ui/UsageApi.js"]
    client_text = texts["contents/ui/UsageClient.qml"]
    provider_text = texts["contents/ui/UsageProvider.qml"]
    main_text = texts["contents/ui/main.qml"]
    full_text = texts["contents/ui/FullRepresentation.qml"]
    compact_text = texts["contents/ui/CompactRepresentation.qml"]
    config_text = texts["contents/config/config.qml"]
    config_xml = texts["contents/config/main.xml"]
    config_ui_text = texts["contents/ui/configGeneral.qml"]

    checks.append(("official endpoint is declared", ENDPOINT in api_text, ENDPOINT))
    checks.append(("client performs a GET request", 'xhr.open("GET", UsageApi.endpoint)' in client_text, ""))
    checks.append(("client sends a bearer token", 'setRequestHeader("Authorization", "Bearer "' in client_text, ""))
    checks.append(("client uses XMLHttpRequest", "new XMLHttpRequest()" in client_text, ""))
    checks.append(("client allows one in-flight request", "if (_xhr !== null)" in client_text, ""))
    checks.append(("client has a request timeout", "xhr.timeout = UsageApi.requestTimeoutMs" in client_text, ""))
    checks.append(("client does not log", "console." not in all_sources, ""))
    checks.append(("client handles transport errors", "xhr.onerror" in client_text and "xhr.ontimeout" in client_text, ""))

    definitions_text = api_text.split("var SAMPLE_WINDOWS")[0]
    window_order = re.findall(r'windowId:\s*"([^"]+)"', definitions_text)
    labels = re.findall(r'label:\s*"([^"]+)"', definitions_text)
    response_keys = re.findall(r'responseKey:\s*"([^"]+)"', definitions_text)
    checks.append(("provider defines three windows in order", window_order == EXPECTED_WINDOW_ORDER, str(window_order)))
    checks.append(("provider keeps the documented labels", labels == EXPECTED_LABELS, str(labels)))
    checks.append(("response keys map to the three windows", response_keys == ["rolling", "weekly", "monthly"], str(response_keys)))
    checks.append(("percent is clamped", "function clampPercent" in api_text and "Math.min(100" in api_text, ""))
    checks.append(("ISO reset timestamps are parsed", "Date.parse" in api_text and "function parseTimestamp" in api_text, ""))
    checks.append(("reset countdown uses absolute timestamps", "remainingSeconds" in api_text and "resetsAt" in api_text, ""))
    checks.append(("missing and malformed payloads are rejected", "Invalid JSON response" in api_text and "Unexpected response from server." in api_text, ""))
    checks.append(("auth errors have a concise message", "401" in api_text and "key rejected" in api_text, ""))
    checks.append(("rate limiting has a concise message", "429" in api_text and "Too many requests" in api_text, ""))
    checks.append(("server errors have a concise message", "Server error (HTTP" in api_text, ""))
    checks.append(("sample data remains documented values", all(f"usedPercent: {percent}" in api_text and f"resetsInSeconds: {seconds}" in api_text for percent, seconds in SAMPLE_VALUES), ""))

    checks.append(("provider stores the API key as config input", 'property string apiKey: ""' in provider_text, ""))
    checks.append(("polling defaults to five minutes", "property int pollIntervalMinutes: 5" in provider_text, ""))
    checks.append(("provider has a demo mode flag", "property bool demoMode: false" in provider_text, ""))
    checks.append(("provider gates requests on a configured key", "function refresh()" in provider_text and "if (!UsageApi.hasApiKey(provider.apiKey))" in provider_text, ""))
    checks.append(("provider starts requests through the client", "provider.client.fetch(provider.apiKey)" in provider_text, ""))
    checks.append(("provider maps responses", "UsageApi.normalizeResponse" in provider_text, ""))
    checks.append(("provider maps HTTP errors", "UsageApi.errorForStatus" in provider_text, ""))
    checks.append(("provider exposes loading, ready, setup, demo, and error states", all(state in provider_text for state in ('"setup"', '"demo"', '"loading"', '"ready"', '"error"')), ""))
    checks.append(("provider summarizes state without secrets", "function summaryText" in provider_text and "Update failed" in provider_text, ""))
    checks.append(("demo data requires both demo mode and no key", "!UsageApi.hasApiKey(provider.apiKey) && provider.demoMode" in provider_text, ""))
    checks.append(("demo data is never the live provider state", 'readonly property bool isSampleData: provider.state === "demo"' in provider_text, ""))
    checks.append(("three placeholder rows survive setup and errors", "UsageApi.defaultEntries" in provider_text and "function resetWindows" in provider_text, ""))
    checks.append(("no request is made for demo or setup", "function refresh()" in provider_text and provider_text.index("function refresh()") < provider_text.index("provider.client.fetch(provider.apiKey)"), ""))

    checks.append(("config model exposes a category", "ConfigModel" in config_text and "ConfigCategory" in config_text, ""))
    checks.append(("config category points at the config page", 'source: "configGeneral.qml"' in config_text, ""))
    checks.append(("API key is a string config entry", '<entry name="apiKey" type="String">' in config_xml, ""))
    checks.append(("poll interval is an integer config entry", '<entry name="pollIntervalMinutes" type="Int">' in config_xml, ""))
    checks.append(("poll interval default is five minutes", re.search(r'<entry name="pollIntervalMinutes" type="Int">.*?<default>5</default>', config_xml, re.S) is not None, ""))
    checks.append(("demo data is an opt-in boolean config entry", '<entry name="showDemoData" type="Bool">' in config_xml and '<default>false</default>' in config_xml, ""))
    checks.append(("config page aliases the API key", "property alias cfg_apiKey:" in config_ui_text, ""))
    checks.append(("config page aliases the poll interval", "property alias cfg_pollIntervalMinutes:" in config_ui_text, ""))
    checks.append(("config page aliases the demo flag", "property alias cfg_showDemoData:" in config_ui_text, ""))
    checks.append(("API key field is password-style", "echoMode: TextInput.Password" in config_ui_text and "PlasmaComponents3.TextField" in config_ui_text, ""))
    checks.append(("config uses stock Plasma controls", all(token in config_ui_text for token in ("KCM.SimpleKCM", "PlasmaComponents3.SpinBox", "PlasmaComponents3.CheckBox")), ""))
    checks.append(("config warns about local key storage", "user home" in config_ui_text and "Rotate the key" in config_ui_text, ""))

    checks.append(("main binds the key from Plasma configuration", "apiKey: Plasmoid.configuration.apiKey" in main_text, ""))
    checks.append(("main binds the poll interval", "pollIntervalMinutes: Plasmoid.configuration.pollIntervalMinutes" in main_text, ""))
    checks.append(("main binds the demo flag", "demoMode: Plasmoid.configuration.showDemoData" in main_text, ""))
    checks.append(("main refreshes when configuration changes", "root.usageProvider.refresh()" in main_text, ""))
    checks.append(("main opens the widget configuration", 'Plasmoid.internalAction("configure")' in main_text and "action.trigger()" in main_text, ""))
    checks.append(("tooltip reports provider state", "toolTipSubText: root.usageProvider.summaryText()" in main_text, ""))

    checks.append(("full view exposes a configuration signal", "signal configureRequested()" in full_text, ""))
    checks.append(("setup state includes a stock settings button", "Open Settings" in full_text and "onClicked: root.configureRequested()" in full_text, ""))
    checks.append(("refresh and retry use a stock button", 'root.provider.state === "error" ? "Retry" : "Refresh"' in full_text and "PlasmaComponents3.Button" in full_text, ""))
    checks.append(("error text is visible without secrets", "provider.errorText" in full_text, ""))
    checks.append(("setup and demo states are explicit", 'root.provider.state === "setup"' in full_text and 'root.provider.state === "demo"' in full_text, ""))
    checks.append(("rows use absolute reset countdowns", "formatResetAt(row.resetsAt)" in full_text, ""))
    checks.append(("compact view reports setup and loading", 'root.provider.state === "setup"' in compact_text and '"loading" ? "…"' in compact_text, ""))
    checks.append(("compact accessible description reports state", "Accessible.description: root.provider.summaryText()" in compact_text, ""))
    checks.append(("compact view keeps system progress bars", "PlasmaComponents3.ProgressBar" in compact_text, ""))

    checks.append(("accessibility metadata is present", "Accessible.name" in checked_qml, ""))
    checks.append(("responsive KDE units are used", "Kirigami.Units" in checked_qml, ""))
    checks.append(("UI uses system-styled Plasma labels", "PlasmaComponents3.Label" in checked_qml, ""))
    checks.append(("UI uses system-styled Plasma progress bars", "PlasmaComponents3.ProgressBar" in checked_qml, ""))
    checks.append(("UI uses system-styled Plasma buttons", "PlasmaComponents3.Button" in full_text, ""))
    checks.append(("compact view uses a system-styled button", "PlasmaComponents3.AbstractButton" in compact_text, ""))
    checks.append(("UI has no hard-coded hex colors", not re.search(r"#[0-9a-fA-F]{6}\b", checked_qml), ""))
    checks.append(("UI does not force font families or sizes", not any(token in checked_qml for token in ("font.family", "font.pointSize", "font.pixelSize", "font.weight")), ""))
    checks.append(("UI sets no custom colors", not re.search(r"\bcolor\s*:", checked_qml), ""))
    checks.append(("UI draws no custom surfaces", not re.search(r"\b(Rectangle|radius|border)\b", checked_qml), ""))
    checks.append(("UI sets no custom opacity", not re.search(r"\bopacity\s*:", checked_qml), ""))
    checks.append(("applet keeps the system background", "backgroundHints" not in main_text and "NoBackground" not in main_text, ""))
    checks.append(("compact representation toggles expansion", "function toggleExpanded" in compact_text and "expanded = !" in compact_text, ""))

    readme_text = texts["README.md"]
    readme_tokens = [
        ENDPOINT,
        "Authorization: Bearer",
        "rolling",
        "weekly",
        "monthly",
        "resetsAt",
        "percent",
        "5 minutes",
        "API key",
        "password",
        "user home",
        "Rotate",
        "Refresh",
        "error",
        "sample",
        "settings",
        "PlasmaComponents3",
        "system",
    ]
    missing_readme = [token for token in readme_tokens if token.lower() not in readme_text.lower()]
    checks.append(("README documents endpoint, contract, key setup, polling, errors, and security", not missing_readme, ", ".join(missing_readme)))
    readme_sections = [
        "## What it is",
        "## What it is not",
        "## Quick start",
        "## Configuration",
        "## API contract",
        "## Behavior and error states",
        "## Project layout",
        "## Verification and testing",
        "## Current status and known limits",
        "## License",
    ]
    missing_sections = [section for section in readme_sections if section not in readme_text]
    checks.append(("README follows the direct project structure", not missing_sections, ", ".join(missing_sections)))
    checks.append(("README marks the endpoint official but changeable", "official" in readme_text.lower() and "can change" in readme_text.lower(), ""))
    checks.append(("README documents that no live API test is used", "live api" in readme_text.lower() and "not" in readme_text.lower(), ""))
    checks.append(("README documents demo data is not live data", "sample" in readme_text.lower() and "demo" in readme_text.lower(), ""))

    test_api_text = texts["tests/tst_usage_api.qml"]
    test_provider_text = texts["tests/tst_usage_provider.qml"]
    checks.append(("API tests cover mapping and clamping", "normalizeResponse" in test_api_text and "clampPercent" in test_api_text, ""))
    checks.append(("API tests cover ISO resets and malformed fields", "resetsAt" in test_api_text and "missingAndMalformed" in test_api_text, ""))
    checks.append(("API tests cover HTTP errors", "errorForStatus(401)" in test_api_text and "errorForStatus(429)" in test_api_text, ""))
    checks.append(("provider tests cover key state", "apiKey" in test_provider_text and 'compare(provider.state, "setup")' in test_provider_text, ""))
    checks.append(("provider tests cover response and failure handling", "applyResponse(200" in test_provider_text and "applyResponse(500" in test_provider_text, ""))
    checks.append(("provider tests cover demo gating", "demoMode" in test_provider_text and "isSampleData" in test_provider_text, ""))
    checks.append(("test target discovers all tests", "-input tests" in texts["Makefile"], ""))

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
