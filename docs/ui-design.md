# DiskMeerkat UI Design

## Status

Approved V1 design. See the [Project Status](../README.md#project-status) for delivery progress.

## Purpose

This document defines how DiskMeerkat presents disk-space monitoring on macOS. The
[Disk Space Monitoring Requirements](disk-space-monitoring.md) are authoritative for capacity semantics,
scheduling, notification suppression, persistence, lifecycle effects, and error handling. This document focuses on
presentation and interaction without copying those rules.

## Product Direction

DiskMeerkat is a menu-bar-only utility. Its `LSUIElement` app does not show a normal Dock or application-switcher icon,
and the user does not need to keep a window visible. The menu bar provides current status and common actions; separate
status and Settings windows provide more detail. Closing any surface leaves monitoring active. Choosing Quit stops the
app and monitoring.

V1 monitors only the startup volume rooted at `/`, with one whole-GB threshold and one interval preset. It does not
present volume selection, storage categories, cleanup recommendations, history, charts, percentage thresholds, or a
system-storage action.

## Menu Bar Experience

The status item uses a disk symbol in the normal state and an attention variant when the user needs to inspect low
space, a permission problem, or a read failure. Color may reinforce state, but symbol shape, accessibility text, and
visible copy communicate it without color.

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
│ [ Check Now ] [ Open Status ]│
│ Settings…                Quit │
└──────────────────────────────┘
```

The available-space value is the visual priority. The volume name, configured threshold, last successful check, and
next scheduled check provide context. `Check Now` always uses the shared monitoring path defined in the
[requirements](disk-space-monitoring.md#scheduling-and-disk-checks) and is disabled while a check is active.

`Open Status` opens or focuses the singleton status window. `Settings…` opens the standard Settings scene. Quit is an
explicit, separated action so closing a popover or window is never confused with stopping monitoring.

The popover reads the next-check deadline from shared monitoring state and does not create a timer for disk checks.
Relative-time text refreshes only while visible and at the coarsest cadence needed for the displayed precision.

## Status Presentation

UI labels describe user-visible outcomes rather than expose the internal `armed` and `suppressed` state names.

| Condition | Status presentation | Available action |
| --- | --- | --- |
| No successful check yet | `Checking disk…`; do not fabricate a capacity | Wait or open Settings |
| Monitoring normally | `Monitoring` with the latest successful value | `Check Now` while idle |
| Low space, alert submitted | `Low disk space · Alert sent`; monitoring remains active | Open Status or Settings |
| Low space, notifications off | `Low disk space · Notifications are off` | Enable notifications or open System Settings |
| Notification submission failed | `Low disk space · Couldn't send alert · Will retry` | Wait for retry |
| Disk read failed | Keep the last successful value, or show `Available space unavailable`; add `Couldn't check disk · Will retry` | `Check Now` while idle |
| Persistence failed | Keep the current in-memory status; explain what could not be saved and that DiskMeerkat will retry | Retry a Settings save when applicable |
| Check in progress | Retain the previous successful value and show lightweight progress | `Check Now` disabled |
| Launch at login needs attention | Keep monitoring status and add a separate login-item explanation | Review Settings |

When an alert was submitted for the current low-space episode, optional detail explains that another alert becomes
eligible only after space recovers above the threshold and later falls below it again. It does not expose a reset
control.

Errors remain scoped. A notification or login-item problem must not make healthy disk monitoring look stopped, and a
disk-read problem must not erase the last known successful value.

## Status and First-run Window

The status window is the one persistent, on-demand detail surface. It shows the same monitoring snapshot as the
popover with room for the current problem, notification state, last and next check, configured values, and relevant
actions. Opening it repeatedly focuses the existing window instead of creating copies or another monitoring runtime.

On the first run, this window also presents a short introduction:

```text
┌────────────────────────────────────┐
│ Welcome to DiskMeerkat             │
│                                    │
│ Monitoring: Macintosh HD           │
│ Alert below: 20 GB                  │
│ Check every: 15 minutes             │
│                                    │
│ [ Enable Notifications ] [ Not Now ]│
└────────────────────────────────────┘
```

The introduction is shown automatically once. `Enable Notifications` is the only control that can initiate the
system authorization request. `Not Now`, closing the window, or otherwise dismissing onboarding records completion
without granting permission; monitoring and menu-bar status remain available. Later launches do not reopen onboarding
automatically, though `Open Status` remains available.

Notification activation opens or focuses this same window at current status. If activation arrives during app launch,
the app finishes composition and then presents the singleton window once.

## Settings Window

V1 uses one compact form instead of tabs:

- **Monitored Volume:** Show the system-provided startup-volume name, or localized `Startup Disk` when it is missing,
  and the current capacity as read-only. Do not use disclosure or picker styling that suggests the volume can be
  changed.
- **Low-space alert:** “Notify me when available space falls below,” followed by a whole-number field and explicit
  decimal `GB` unit. The accepted range is 1 through 1,000,000 GB; the default is 20 GB.
- **Check interval:** Offer exactly 5 minutes, 15 minutes, 30 minutes, 1 hour, 6 hours, and 24 hours; the default is
  15 minutes.
- **Notifications:** Show the actual authorization state and either `Enable Notifications` or a useful route to
  System Settings when permission is denied.
- **Launch at Login:** Provide an opt-in switch, off by default, accompanied by actual system status when the request
  needs approval, was changed outside the app, or failed.

Threshold and interval edits are local drafts. Invalid threshold text shows a nearby, specific explanation and does
not replace the last valid value. The Save action is enabled only for a valid supported threshold and interval. Saving
persists the values, closes the draft state, and invokes the immediate-check and schedule-replacement behavior defined
in the [requirements](disk-space-monitoring.md#configuration). Cancel or closing Settings discards unsaved drafts.
If persistence fails, keep the draft and prior committed values visible, show an inline retryable error, and do not
present the new schedule as active.

Settings does not expose notification suppression as a toggle. Resetting it manually would defeat the one-alert-per-
episode behavior.

## Notification Permission

DiskMeerkat never displays the system notification prompt merely because the app launched or a disk check ran.
Presentation depends on the current authorization state:

| Authorization state | Presentation |
| --- | --- |
| Not determined | Explain the benefit and show `Enable Notifications` |
| Authorized | Show that alerts are enabled; do not prompt |
| Denied | Explain that monitoring continues without alerts and offer `Open System Settings` |
| Unavailable or error | Explain the problem without implying monitoring stopped |

After `Enable Notifications` is selected, the app may show the system prompt once. A grant dismisses the permission
callout and triggers the behavior specified in the requirements; a denial updates the explanation without repeatedly
prompting. Permission is not a gate for viewing status, editing configuration, checking manually, or dismissing first
run.

## Launch at Login

Launch at login uses the main app's `SMAppService` registration and remains separate from monitoring health.

| Actual state | Settings presentation |
| --- | --- |
| Disabled | Switch off; user may opt in |
| Enabled | Switch on |
| Approval required or denied | Do not show a successful enabled state; explain the required system action |
| Changed outside DiskMeerkat | Refresh to the actual state and explain the mismatch when useful |
| Operation failed or unavailable | Restore the actual switch state and show an inline retryable error |

Changing this switch is an explicit user action. Failure does not alter disk configuration, close the app, or stop the
current monitoring process.

## Notification Content and Activation

A low-space notification is direct and contains the values needed to understand it:

```text
Disk space is low
Macintosh HD has 18.4 GB available, below your 20 GB limit.
```

Activating the notification opens DiskMeerkat's singleton status window. V1 includes no custom notification action and
no button that opens system storage management; users free space with their preferred system or third-party tools.

## Accessibility and Formatting

- Provide VoiceOver labels for the menu-bar status, capacity indicator, progress, and every icon-only control.
- Do not communicate healthy, warning, or error states with color alone.
- Make every popover, status-window, and Settings action reachable by keyboard with a visible focus state.
- Keep layouts usable with larger accessibility text and avoid encoding important information only in a graphical
  meter.
- Use locale-aware text with decimal capacity semantics: `1 GB = 1,000,000,000 bytes`.
- Show whole configured thresholds such as `20 GB`; routine measured values may use a concise fractional value such as
  `82.4 GB`.
- When normal rounding would contradict the exact strict comparison, add precision and relationship copy. For example,
  show `19.999 GB available · below 20 GB limit` instead of `20.0 GB available` for a value below the limit. If the
  byte-level difference cannot be made clear at practical precision, use `just below` or `just above` with the exact
  limit.
- Use consistent locale-aware relative time for last and next checks; never imply an exact future check while one is
  active or pending.

## Interaction Acceptance

The behavioral outcomes remain in the [requirements acceptance criteria](disk-space-monitoring.md#acceptance-criteria).
The V1 presentation additionally satisfies these observable interactions:

1. First launch shows one dismissible onboarding/status window without automatically prompting for notifications.
2. Closing every window leaves the menu-bar item and monitoring active; Quit removes them and stops monitoring.
3. Invalid Settings drafts show inline errors, cannot be saved, and do not change the displayed committed values. A
   valid draft whose persistence fails remains editable beside the prior committed values and does not appear applied.
4. During a check, progress is visible, the last successful capacity remains readable, and `Check Now` is disabled.
5. Selecting `Enable Notifications` is the only route to the system prompt; denial leaves monitoring usable and
   explained.
6. Notification activation focuses one status window whether it was closed, already open, or requested during launch.
7. Launch-at-login approval, denial, external change, and failure show actual state instead of a falsely successful
   toggle.
8. Near a threshold boundary, capacity text never visually contradicts whether the app considers the disk low or
   recovered.

## Architecture Boundary

Reusable views, presentation models, draft validation, formatting, accessibility identifiers, and state-to-copy
mapping belong in `Packages/DiskMeerkatApp`. The thin Xcode app target owns scene declarations, `LSUIElement`, app and
window activation, notification launch routing, and production dependency composition. Follow the ownership rules in
the [Development Guide](development.md#package-first-architecture).
