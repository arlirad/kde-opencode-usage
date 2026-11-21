# OpenCode Usage

A compact KDE Plasma 6 plasmoid that shows OpenCode Go usage for the 5-hour, weekly, and monthly windows. Each row contains a usage badge, a reset label, and a horizontal usage track. The widget uses only Qt 6 and KDE Plasma/QML modules.

The current data is a static sample. No network requests, credentials, timers, or OpenCode integration are implemented yet.

## Project layout

```
metadata.json                       Plasma/Applet package metadata
Makefile                            verify, install, upgrade, uninstall targets
contents/ui/main.qml                PlasmoidItem entry point
contents/ui/FullRepresentation.qml  desktop widget layout
contents/ui/CompactRepresentation.qml panel layout
contents/ui/UsageRow.qml            reusable label/badge/reset/track row
contents/ui/UsageBar.qml            shared progress track and fill
contents/ui/UsageBadge.qml          themed outlined percentage badge
contents/ui/UsageResetLabel.qml     themed subordinate reset text
contents/ui/UsageProvider.qml       isolated data provider and formatting
contents/ui/UsagePalette.js         theme-derived contrast helpers for progress colors
tests/verify_project.py             project, theme, and sample-label checks
tests/contrast_probe.py             Breeze light/dark WCAG contrast checks
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

The verifier checks the package layout, metadata fields, the three sample windows, the expected badge and reset labels, accessibility metadata, theme-derived color/font usage, and README coverage of the sample data and API status. It does not require a running Plasma session. `make verify` also runs a contrast probe against the installed Breeze Light and Breeze Dark color schemes, checking badge and reset text against WCAG AA (4.5:1), the unfilled track against the card, the fill against the unfilled track, and the compact focus ring, all against the 3:1 non-text target.

Optional QML syntax check:

```sh
/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml contents/ui/*.qml
```

The Qt 6 `qmllint` path varies by distribution. The verifier itself has no KDE dependency.

Optional headless compact-activation test:

```sh
make test-ui
```

This runs `tests/tst_compact_activation.qml` with the Qt 6 QML test runner under Xvfb, with `QT_QPA_PLATFORMTHEME=kde` so `Kirigami.Theme` resolves the actual KDE palette rather than a plain Qt fallback. It verifies that clicking, Space, and Return toggle the compact representation's `expanded` state, and that the focus ring has at least 3:1 contrast against the button background. Override `QMLTESTRUNNER` if the runner is installed elsewhere.

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

On a desktop containment the full three-row card is shown. In a panel the compact representation shows the highest usage percentage and three miniature tracks. A shell restart is normally unnecessary; if the widget does not appear, restart Plasma explicitly for your session.

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

- Colors and fonts come from `Kirigami.Theme` so the widget follows the active KDE/Plasma theme. The card uses `backgroundColor`; badge and reset text use readable `textColor`. Both full rows and compact mini-bars share `UsageBar.qml`: its unfilled track is the lightest theme-text blend over the card that still reaches 3:1, while its fill is the theme highlight accent, darkened or lightened only as far as needed to reach 3:1 against that track. In Breeze Light this yields a deep blue fill; in Breeze Dark a light blue fill. The semantic `positiveTextColor` remains as the decorative badge outline. There is no custom color palette or branding palette.
- Fonts use the theme's `defaultFont` and `smallFont` without forced families, sizes, or weights. Sizes use `Kirigami.Units` so the widget follows display scaling.
- Rows show title and badge together on the left with the reset label right-aligned on the same line when space allows. Below that breakpoint, the reset label reflows to its own right-aligned line above the track, keeping the title and badge visible at the supported 14-grid-unit minimum and at 256 px.
- Usage rows are static content. Each row exposes a combined accessible name (`title, badge, reset`), and decorative children are hidden from assistive technology.
- The compact panel representation is a focusable Plasma `AbstractButton`; clicking or activating it with the keyboard toggles the plasmoid's expanded full view. It retains an accessible button role, name, and the full usage summary as its description. The focus ring uses 2 px of readable `textColor` rather than the lower-contrast focus color.
- The widget sets `PlasmaCore.Types.NoBackground` because it draws its own card background from theme colors.
