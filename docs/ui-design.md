# DiskMeerkat UI Design

## Status

Draft for product review.

## Purpose

This document describes how DiskMeerkat presents disk-space monitoring on macOS. The
[Disk Space Monitoring Requirements](disk-space-monitoring.md) remain authoritative for monitoring behavior,
notification suppression, persistence, and error handling. This document focuses on presentation and interaction
without repeating those rules.

## Product Direction

DiskMeerkat should be a menu-bar-first utility. Monitoring runs while the app is open, but the user should not need to
keep a window visible. The menu bar provides current status and common actions; a separate Settings window contains
configuration and permission details. Closing Settings does not stop monitoring. Quitting the app is an explicit menu
action.

The first version should stay intentionally small: one monitored volume, one threshold, and one schedule. It should
not present storage categories, cleanup recommendations, history, or charts.

## Menu Bar Experience

The status item uses a disk symbol in the normal state and an attention variant when the user needs to inspect low
space, a permission problem, or a read failure. Color may reinforce state, but shape and text must communicate it
without relying on color alone.

Selecting the status item opens a compact popover:

```text
┌──────────────────────────────┐
│ DiskMeerkat       Monitoring │
│                              │
│ Macintosh HD                 │
│ 82.4 GB available            │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│ Alert below 20 GB            │
│                              │
│ Last checked: Just now       │
│ Next check: In 15 minutes    │
│                              │
│ [ Check Now ]   [ Settings ] │
│                         Quit │
└──────────────────────────────┘
```

The available-space value is the visual priority. The volume name, configured threshold, last successful check, and
next scheduled check provide context. The proposed `Check Now` control remains subject to product approval. If it is
included, it uses the same serialized check path and state transitions as a scheduled check and is disabled while a
check is already running.

The popover reads the next-check deadline from shared monitoring state and does not create a second monitoring timer.
Relative-time text refreshes only while the popover is visible, at the coarsest cadence needed for its displayed
precision.

## Status Presentation

UI labels should describe user-visible outcomes rather than expose the internal `armed` and `suppressed` state names.

| Condition | Popover presentation | User action |
| --- | --- | --- |
| No successful check yet | `Checking disk…` without displaying a fabricated capacity value | Wait |
| Monitoring normally | `Monitoring` with the latest successful value | Optional `Check Now` |
| Low space, alert submitted | `Low disk space · Alert sent` while monitoring remains active | Open Settings or system storage management |
| Notifications unavailable | `Monitoring, but notifications are off` | `Open System Settings` |
| Notification submission failed | `Low disk space · Couldn’t send alert · Will retry` while monitoring remains active | Wait for retry |
| Disk read failed | Keep the last successful value, or show `Available space unavailable` if none exists; show `Couldn’t check disk · Will retry` | Optional `Check Now` |
| Check in progress | Show lightweight progress and retain the previous successful value when available | Wait; duplicate checks are disabled |

When an alert has already been submitted for the current low-space episode, an optional detail explains that another
alert becomes eligible only after available space recovers above the threshold and later falls below it again.

## Settings Window

Use one compact form rather than multiple tabs for the first version:

- **Monitored Volume:** show the selected local volume and its current capacity. If V1 monitors only the startup
  volume, present this as read-only rather than suggesting it can be changed.
- **Low-space alert:** phrase the control as “Notify me when available space falls below,” followed by a numeric field
  and an explicit unit.
- **Check interval:** provide understandable presets rather than requiring duration syntax.
- **Notifications:** show the current authorization state and either `Enable Notifications` or `Open System Settings`.
- **Launch at Login:** offer an explicit opt-in switch if background startup is included in V1.

Invalid threshold input remains an uncommitted draft, displays an inline explanation, and does not replace the last
valid persisted value. Valid changes take effect without restarting the app. Settings should not expose notification
suppression as a toggle because manually resetting it would encourage duplicate alerts.

## First Launch and Permissions

On first launch, show a short introduction identifying the monitored volume and the proposed default threshold and
interval. Notification authorization is requested only after the user selects `Enable Notifications`; it is not
triggered by a background check. If authorization is denied, monitoring continues and the UI explains that alerts
cannot currently be delivered without repeatedly prompting.

The first-run flow must remain dismissible so the app can still report disk status without notification permission.

## Notification Content

A low-space notification should be direct and contain the values needed to understand it:

```text
Disk space is low
Macintosh HD has 18.4 GB available, below your 20 GB limit.
```

Activating the notification opens DiskMeerkat at the relevant status. An action that opens macOS storage management
may be added only if the destination is reliable on the supported macOS version.

## Accessibility and Formatting

- Provide VoiceOver labels for the menu-bar status, capacity indicator, and all icon-only controls.
- Do not communicate healthy, warning, or error states with color alone.
- Use locale-aware capacity and relative-time formatting while preserving the exact byte values used by monitoring.
- Use a consistent capacity unit and enough precision that displayed values never contradict the strict threshold
  comparison near a rounding boundary.
- Keep text usable with larger accessibility sizes and avoid encoding important content only in a graphical meter.
- Ensure every popover and Settings action is reachable by keyboard.

## Architecture Boundary

Reusable views, presentation models, input validation, and state-to-copy mapping belong in
`Packages/DiskMeerkatApp`. The thin Xcode app target owns scene declarations and macOS integration such as the menu-bar
item, notification authorization, application lifecycle, and launch-at-login registration. Follow the ownership rules
in the [Development Guide](development.md#package-first-architecture).

## Recommended V1 Decisions

The wireframes use illustrative values, not confirmed requirements. Before implementation, confirm the related open
decisions in the monitoring requirements. The recommended starting point is:

- monitor the startup volume only;
- use an absolute threshold displayed in `GB`;
- default to a `20 GB` threshold and a `15 minute` interval;
- offer a small interval preset list;
- offer launch at login without enabling it automatically; and
- keep the app menu-bar-first, with no persistent main window.
