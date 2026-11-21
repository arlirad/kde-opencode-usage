# OpenCode Usage

A KDE Plasma 6 plasmoid that shows OpenCode Go usage for the rolling 5-hour, weekly, and monthly windows using the official usage endpoint.

## What it is

- A panel and desktop widget with three usage rows in a fixed order: 5-hour window, Weekly, Monthly.
- A live client for `GET https://opencode.ai/zen/go/v1/usage` using the configured OpenCode Go API key.
- A stock Plasma UI built from `PlasmaComponents3` labels, buttons, text fields, and progress bars. It does not define colors, fonts, borders, radii, opacity, card surfaces, or a custom palette; the active system theme supplies them.
- A small provider layer: `UsageApi.js` owns parsing and normalization, `UsageClient.qml` owns the single HTTP request, and `UsageProvider.qml` owns configuration state, polling, and formatting.

## What it is not

- Not an official OpenCode application and not affiliated with OpenCode.
- Not a history, billing, or quota-management tool. It displays the current response only.
- Not a secure credential store. The API key is kept in Plasma's normal widget configuration, which is local user configuration and is not encrypted by this widget.
- Not dependent on Python, curl, or an external helper process at runtime. The request runs in QML through `XMLHttpRequest`.
- Not covered by a live API test. The repository tests do not use a real key or contact the endpoint.

## Quick start

1. Install or upgrade the package:

   ```sh
   make install
   # or, after an initial install:
   make upgrade
   ```

2. Add the widget from Plasma's **Add Widgets** dialog and search for **OpenCode Usage**.

3. Open the widget configuration, enter the API key, and apply the settings. From an unconfigured widget, use the **Open Settings** button in the full view, or right-click the widget and choose **Configure OpenCode Usage**.

4. The widget requests usage immediately after a key is applied and then once per polling interval. The centered action row at the bottom opens the OpenCode Go console or refreshes usage manually.

## Configuration

The configuration page is `contents/ui/configGeneral.qml`, declared in `contents/config/config.qml` and backed by `contents/config/main.xml`.

| Setting | Config key | Default | Meaning |
| --- | --- | --- | --- |
| OpenCode Go API key | `apiKey` | empty | Bearer token for the usage endpoint. The field uses password-style display, but storage is plain local configuration. |
| Refresh every | `pollIntervalMinutes` | 5 | Minutes between automatic requests. Values are limited to 1 through 1440. |

The key is stored by Plasma in the widget's configuration under the local user home directory (typically the applet configuration file). It is not encrypted, and it may be readable by anything that can read that user's configuration. Rotate the key in OpenCode if it may have been exposed, then enter the new key here.

An empty or whitespace-only key counts as unconfigured. No request is made without a key. The widget stays in setup state with placeholder rows and never displays fabricated usage values.

## API contract

Request:

```http
GET https://opencode.ai/zen/go/v1/usage
Authorization: Bearer <api-key>
Accept: application/json
```

Expected response shape from the current official documentation:

```json
{
  "usage": {
    "rolling": { "status": "ok", "percent": 10, "resetsAt": "2026-05-01T14:00:00Z" },
    "weekly": { "status": "ok", "percent": 4, "resetsAt": "2026-05-03T12:00:00Z" },
    "monthly": { "status": "ok", "percent": 2, "resetsAt": "2026-06-01T12:00:00Z" }
  }
}
```

Mapping rules:

- `usage.rolling` maps to `five_hour` and the **5-hour window** row; `usage.weekly` maps to the **Weekly** row; `usage.monthly` maps to the **Monthly** row. The order is fixed.
- `percent` is treated as 0 through 100 and clamped. Missing, non-numeric, or non-finite values become 0.
- `resetsAt` is an absolute timestamp. ISO 8601 strings are parsed with `Date.parse`; numeric Unix seconds or milliseconds are also accepted. A past timestamp displays a zero countdown.
- A missing or malformed window still produces its row with 0 percent and no reset time. A missing `usage` envelope, invalid JSON, or a non-object payload is an error.
- `status` is accepted but not used for display. Only `percent` and `resetsAt` drive the rows.

The endpoint is official, but the current response contract and endpoint availability can change. If the shape changes, `UsageApi.normalizeResponse` is the single place to update the mapping.

## Behavior and error states

- The provider sends one request at a time. A second manual refresh or timer tick is ignored while a request is in flight.
- Each request has a 15-second QML timer watchdog. The Qt 6.12 QML `XMLHttpRequest` exposes only `onreadystatechange`, so the watchdog aborts the request, clears the in-flight slot, and reports a timeout through the normal failure path. No XHR timeout or error properties are used. Network errors, timeouts, invalid JSON, and HTTP errors produce a concise error state.
- The automatic interval is 5 minutes by default. The full view has a centered action row at the bottom, below the usage rows and any setup or error text. **Open OpenCode Go** on the left opens `https://opencode.ai/console/go` in the external browser; **Refresh** on the right requests usage immediately. While the last request failed, the right button is labeled **Retry**. Both are normal-width stock buttons and do not fill the row.
- `401` and `403`: the API key is rejected. `429`: too many requests. `5xx`: server error. A status outside those groups is reported as a generic HTTP failure. Response bodies and keys are never shown or logged.
- With no key, the provider stays in setup state, the full view shows setup text plus **Open Settings**, and the three rows render placeholders (`—`) with empty progress bars. The compact view shows **Setup**. No usage values are fabricated.
- After a successful response, a later failure keeps the last live rows and reports the update error in the tooltip, error label, and summary. The widget never substitutes fabricated values for live data.
- Reset labels are recomputed from the absolute `resetsAt` value against the current time, refreshed once per minute, so they count down between polls.
- The tooltip and compact accessible description report setup, loading, ready, or error state without including the key or response secrets.

## Project layout

```
metadata.json                       Plasma/Applet metadata; package id org.opencode.usage
contents/config/main.xml            KConfigXT entries: apiKey, pollIntervalMinutes
contents/config/config.qml          Plasma configuration model
contents/ui/configGeneral.qml       Stock Plasma/Kirigami settings page
contents/ui/main.qml                PlasmoidItem entry point and configuration wiring
contents/ui/FullRepresentation.qml  desktop view, setup and error states, centered bottom action row
contents/ui/CompactRepresentation.qml panel view and accessible summary
contents/ui/UsageRow.qml            title, percent, reset, and stock progress bar
contents/ui/UsageProvider.qml       state, polling, formatting, and row model
contents/ui/UsageClient.qml         single in-flight XMLHttpRequest transport
contents/ui/UsageApi.js             endpoint, window mapping, timestamp parsing, errors
tests/verify_project.py             structural, contract, style, and README checks
tests/tst_usage_api.qml             mapping, clamping, timestamp, and error tests
tests/tst_usage_client.qml          watchdog timeout, recovery, and transport tests
tests/tst_usage_provider.qml        config, response, failure, and setup-state tests
tests/tst_full_representation.qml   bottom refresh button and narrow-width layout tests
tests/tst_compact_activation.qml    headless compact activation test
```

## Verification and testing

```sh
make verify
make test-ui
/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml contents/ui/*.qml contents/config/*.qml tests/*.qml
```

`make verify` checks package structure, the endpoint and response mapping, config entries, setup and error states, stock-control usage, and README coverage. `make test-ui` runs all `tests/tst_*.qml` files offscreen with the KDE platform theme. The QML tests cover normalized response mapping, ISO and numeric reset timestamps, missing and malformed fields, percent clamping, API/error messages, key gating, successful and failed responses, one-in-flight behavior, watchdog timeout recovery, late callbacks, setup placeholders, and the centered bottom action row at narrow and normal widths.

There is no live API test. Tests must not use a real key and must not contact the production endpoint. `qmllint` may report `missing-property` warnings for `Plasmoid.configuration.*`; those properties come from the KConfigXT file at runtime.

## Current status and known limits

- The endpoint and response shape are implemented from the current official documentation; availability and compatibility are not guaranteed by this project.
- The API key is stored as plain local Plasma configuration, not in KWallet or another secret store. Password-style display only masks the field.
- The widget polls only while it is loaded. It does not retain history, cache between sessions, or back off beyond the fixed polling interval.
- If the endpoint returns additional windows, they are ignored. Only the three documented windows are displayed.
- No response data or credentials are logged by the widget, but local configuration may still be readable by other processes running as the same user.

## License

MIT
