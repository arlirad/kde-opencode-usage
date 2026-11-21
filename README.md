# OpenCode Usage

A compact KDE Plasma 6 plasmoid that shows OpenCode Go usage for the 5-hour, weekly, and monthly windows. Each row contains a usage percentage label, a reset label, and a system progress bar. The widget uses only Qt 6 and KDE Plasma/QML modules.

The current data is a static sample. No network requests, credentials, timers, or OpenCode integration are implemented yet.

## Project layout

```
metadata.json                       Plasma/Applet package metadata
Makefile                            verify, install, upgrade, uninstall targets
contents/ui/main.qml                PlasmoidItem entry point
contents/ui/FullRepresentation.qml  desktop widget layout
contents/ui/CompactRepresentation.qml panel layout
contents/ui/UsageRow.qml            system-styled title/percent/reset/progress row
contents/ui/UsageProvider.qml       isolated data provider and formatting
tests/verify_project.py             project, sample-label, and system-style checks
tests/tst_compact_activation.qml    headless compact click/keyboard activation test
```

## Requirements

- KDE Plasma 6.0 or newer (`metadata.json` declares `X-Plasma-API-Minimum-Version` 6.0)
- Qt 6 with QML, Qt Quick, and Qt Quick Layouts
- KDE Frameworks 6 with Kirigami
- `kpackagetool6` for installation
- Python 3 for the verification script

## Verify

```sh
make verify
```

or directly:

```sh
python3 tests/verify_project.py
```

The verifier checks the package layout, metadata fields, the three sample windows, the expected percentage and reset labels, accessibility metadata, the use of system-styled Plasma controls, the absence of custom colors/surfaces/fonts, and README coverage of the sample data and API status. It does not require a running Plasma session.

Optional QML syntax check:

```sh
/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml contents/ui/*.qml
```

The Qt 6 `qmllint` path varies by distribution. The verifier itself has no KDE dependency.

Optional headless compact-activation test:

```sh
make test-ui
```

This runs `tests/tst_compact_activation.qml` with the Qt 6 QML test runner offscreen, with `QT_QPA_PLATFORMTHEME=kde` so the active KDE palette and Plasma controls resolve instead of a plain Qt fallback. It verifies that clicking, Space, and Return toggle the compact representation's `expanded` state. Override `QMLTESTRUNNER` if the runner is installed elsewhere.

## Build and install

There is no compilation step. Install the package directory with:

```sh
make install
```

which is equivalent to:

```sh
kpackagetool6 --type Plasma/Applet --install .
```

After editing an installed copy:

```sh
make upgrade
```

or:

```sh
kpackagetool6 --type Plasma/Applet --upgrade .
```

Remove it with:

```sh
make uninstall
```

or:

```sh
kpackagetool6 --type Plasma/Applet --remove org.opencode.usage
```

## Run

1. Install or upgrade the package.
2. Right-click the desktop or panel, enter edit mode, and choose **Add Widgets**.
3. Search for **OpenCode Usage** and add it.

On a desktop containment the full three-row layout is shown. In a panel the compact representation shows the highest usage percentage and three miniature progress bars. A shell restart is normally unnecessary; if the widget does not appear after an upgrade, restart Plasma explicitly for your session.

There is no standalone executable. `plasmashell` hosts the QML package.

## Assumed sample data

The provider lives in `contents/ui/UsageProvider.qml` and is marked `isSampleData: true`. Sample values are encoded as percentages and reset durations in seconds, then formatted by the provider.

| Title | `usedPercent` | `resetsInSeconds` | Badge | Reset label |
| --- | ---: | ---: | --- | --- |
| 5-hour window | 10 | 14820 | 10% used | Resets in 4h 7m |
| Weekly | 4 | 133200 | 4% used | Resets in 1d 13h |
| Monthly | 2 | 2588400 | 2% used | Resets in 29d 23h |

The UI consumes only this normalized shape:

```js
{
    windowId: "five_hour",      // stable identifier
    label: "5-hour window",     // display title
    usedPercent: 10,            // assumed 0..100 scale
    resetsInSeconds: 14820      // relative time from now
}
```

`UsageProvider.applyUsage(entries)` replaces the sample rows with an array of entries in that shape. `formatPercent`, `formatUsagePercent`, `formatReset`, `usageRatio`, and `summaryText` are the only formatting entry points used by the UI.

## Unknown real API contract

The real OpenCode Go API contract is unknown. This project intentionally makes no assumptions about:

- the endpoint, HTTP method, or required headers
- authentication or how credentials would be stored
- the response envelope and field names
- whether usage is a percentage (0-100), a fraction (0-1), or a raw count with a limit
- whether resets are absolute timestamps or relative durations, and in which timezone
- update cadence, caching, failure states, and rate limits

Only the normalized provider shape above is assumed. When the API is confirmed, its response should be mapped into that shape and passed to `applyUsage()`; the presentation components should not need to change. Until then, the displayed values are sample data only.

## Design notes

- The widget is intentionally unstyled. It uses stock `PlasmaComponents3.Label`, `PlasmaComponents3.ProgressBar`, and `PlasmaComponents3.AbstractButton` controls, so the active Plasma style supplies the palette, fonts, and progress-bar artwork. The package does not override the applet background, draw its own card, or define colors, fonts, borders, radii, opacity, or bar drawing.
- `Kirigami.Units` is used only for layout geometry: content margins, row spacing, the compact size, and the 17-grid-unit breakpoint that reflows the reset label.
- Rows show title and percentage on the left with the reset label right-aligned on the same line when space allows. Below that breakpoint, the reset label reflows to its own right-aligned line above the progress bar, keeping the title and percentage visible at the supported 14-grid-unit minimum and at 256 px.
- Usage rows are static content. Each row exposes a combined accessible name (`title, percentage, reset`), and its decorative labels and progress bar are hidden from assistive technology.
- The compact panel representation is a focusable `PlasmaComponents3.AbstractButton`; clicking or activating it with the keyboard toggles the plasmoid's expanded full view. It retains an accessible button role, name, and the full usage summary as its description, while focus and hover behavior come from the system control.
- The applet keeps the default Plasma background; it does not set `backgroundHints` or `NoBackground`.
