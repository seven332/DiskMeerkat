# Disk Space Monitoring Requirements

## Status

Approved for V1 implementation. See the [Project Status](../README.md#project-status) for delivery progress.

The companion [UI Design](ui-design.md) defines the approved menu-bar, Settings, status-window, and notification
experience. This document is authoritative for monitoring behavior, state transitions, persistence, and errors.

## Summary

DiskMeerkat monitors the startup volume at a configurable interval. When the available space falls below a
configurable threshold, the app submits a notification.

The app must not repeat the notification while the disk remains at or below the threshold. A new notification becomes
eligible only after a successful check observes that the available space has risen above the threshold and a later
check observes that it has fallen below the threshold again.

## Goals

- Detect low disk space without requiring the user to check manually.
- Let the user choose an approved check interval and whole-GB low-space threshold.
- Send one useful notification for each distinct low-space episode.
- Avoid repeated notifications while the disk remains low on space.
- Preserve monitoring configuration and notification suppression across app restarts.
- Keep monitoring active while the menu-bar app is running, even when no window is open.

## Non-goals

V1 does not:

- Delete files, free disk space, or recommend files for deletion.
- Predict when the disk will become full.
- Send a notification when space recovers.
- Maintain disk-usage history or charts.
- Monitor remote, network, or multiple local volumes.
- Provide a volume picker or percentage-based threshold.
- Provide a notification action that opens macOS storage management.

## Terminology

- **Monitored volume:** The startup volume rooted at `/`. V1 always monitors this one volume.
- **Available space:** The non-negative `volumeAvailableCapacityForImportantUsage` value for the monitored volume.
- **Check interval:** One of the supported durations between completed scheduled checks.
- **Low-space threshold:** The exact byte count represented by the configured whole decimal-GB value.
- **Armed:** A low-space notification may be submitted when the next successful check is below the threshold.
- **Suppressed:** A low-space notification was submitted for the current episode and another must not be submitted until
  recovery is observed.
- **Low-space episode:** The period beginning when an armed check first observes space below the threshold and ending
  when a later successful check observes space above the threshold.

## Functional Requirements

### Monitored Volume and Available Capacity

1. V1 monitors exactly the startup volume represented by the file URL `/`.
2. The monitored volume is fixed. The app does not present a volume picker or maintain per-volume state.
3. A disk check reads Foundation's `volumeAvailableCapacityForImportantUsage` for `/`. This definition, which can
   account for space the system may make available for important use, is used consistently for comparison and display.
4. A successful disk check returns the non-negative capacity as an exact byte count. The app uses a non-empty
   system-provided volume name when available and otherwise uses the localized fallback `Startup Disk`; a missing name
   alone does not fail the capacity reading.
5. A missing or negative capacity, or an error while reading the resource value, is a failed check. It is never
   converted to zero available space.
6. Capacity units are decimal: `1 GB = 1,000,000,000 bytes` and `1 PB = 1,000,000 GB`.
7. User-visible capacity uses the same decimal-byte semantics as threshold comparison. Near a threshold boundary, the
   display adds enough precision, and if necessary an explicit below/above qualifier, so rounding cannot contradict
   the strict comparison result.

### Configuration

1. The low-space threshold is an absolute whole-number value in decimal `GB`.
2. Supported thresholds are 1 GB through 1 PB inclusive, or 1 through 1,000,000 in the numeric field. The default is
   20 GB.
3. The app persists the threshold as its exact byte count, not a rounded floating-point value.
4. Supported check intervals are 5 minutes, 15 minutes, 30 minutes, 1 hour, 6 hours, and 24 hours. The default is
   15 minutes.
5. Settings edits remain drafts until saved. Invalid or out-of-range drafts do not replace the last valid
   configuration, restart the schedule, or request a check.
6. Saving valid settings first persists the configuration, then cancels and replaces the existing interval schedule,
   and requests one immediate check through the shared serialized check path.
7. If configuration persistence fails, the last committed configuration and schedule remain active, no check is
   requested for the failed save, and the UI keeps the draft available with an actionable error.
8. Valid configuration changes take effect without restarting the app and survive subsequent launches.
9. A threshold change is evaluated by the next successful check using the normal notification transition table.
   Changing the threshold does not directly reset notification suppression.
10. Changing only the interval does not change the armed or suppressed state.

### Scheduling and Disk Checks

1. The app requests an immediate check when monitoring starts, then schedules the next interval from the completion of
   each check.
2. Only one disk-space check may be active at a time.
3. Check triggers from startup, the interval, wake, settings save, notification-permission grant, and `Check Now` use
   one serialized path. Triggers received during an active check coalesce into at most one follow-up check.
4. A changed interval cancels and replaces the existing schedule rather than creating another timer. The replacement
   schedule starts from completion of the settings-triggered check.
5. Missed intervals caused by sleep, suspension, or the app not running do not produce catch-up checks.
6. After a wake event, the app requests at most one immediate check through the coalescing path and then resumes the
   configured schedule from check completion.
7. A failed or invalid disk-space read does not send a low-space notification or change the notification state. The app
   exposes the failure and retries on a later check.
8. `Check Now` uses the same reading, transition, notification, persistence, and scheduling behavior as every other
   trigger. The UI disables it while a check is active; a trigger that races with the active check still follows the
   coalescing rule.
9. Quitting stops monitoring, cancels scheduled work, and prevents a pending or stale result from mutating state after
   shutdown.

### Notification State

The monitoring logic has two persistent states: `armed` and `suppressed`.

| Current state | Check result | Notification | Next state |
| --- | --- | --- | --- |
| Armed | Available space is below the threshold and the notification request is submitted successfully | Submit one low-space notification | Suppressed |
| Armed | Available space is below the threshold but a notification cannot be submitted | None | Armed |
| Armed | Available space equals or exceeds the threshold | None | Armed |
| Suppressed | Available space is at or below the threshold | None | Suppressed |
| Suppressed | Available space is above the threshold | None | Armed |
| Either state | Check fails or returns an invalid value | None | Unchanged |

The boundary comparisons are intentionally strict:

- A notification is eligible only when `availableSpace < threshold`.
- Suppression is cleared only when `availableSpace > threshold`.
- A value equal to the threshold neither sends a notification nor clears suppression.

Remaining below the threshold therefore produces one notification request after a successful submission. After
recovery is observed, a later drop below the threshold starts a new low-space episode and may produce one new request.

### State Persistence and Configuration Changes

1. The app persists the valid configuration and whether notifications are armed or suppressed.
2. Restarting while notification state is suppressed must not produce another request merely because the disk remains
   low on space.
3. On the first successful check after launch, the app evaluates persisted state using the normal transition table.
4. If persisted state is suppressed and the first check is above the threshold, notifications become armed again
   without sending a recovery notification.
5. Lowering the threshold may rearm notifications when the next successful reading is above the new threshold.
6. Raising the threshold may make an armed low-space notification eligible on the next successful reading.
7. A failed read or failed notification submission never changes persisted notification state.
8. State needed to remember that first-run onboarding was completed also survives relaunches.
9. Each actual `armed` or `suppressed` transition updates the serialized in-memory state and immediately attempts to
   persist it. A persistence failure is exposed to the UI and retried without rolling the in-process transition back.
10. If suppression persistence fails after an accepted notification submission, the current process remains
    suppressed and must not submit another request for the same episode. The app retries the durable write.
11. Notification submission and local persistence cannot be atomic. A process termination after the system accepts a
    request but before suppression is durably written can restore the prior armed state on relaunch and allow a
    duplicate request. Implementation minimizes and tests this known boundary; it must not claim crash-safe
    exactly-once delivery.

Persisting suppression favors avoiding duplicate notifications. If the app was not running, it cannot infer whether
the disk briefly recovered and became low again during that time.

### Notification Authorization and Delivery

1. The app reads the current notification authorization state when monitoring starts, but it does not prompt on launch
   or from a disk check.
2. The app requests authorization only after the user selects `Enable Notifications`.
3. Granting authorization requests one immediate check through the shared coalescing path. Denial does not request a
   check or cause another permission prompt.
4. The app clearly exposes not-determined, denied, unavailable, and authorized notification states while disk
   monitoring continues.
5. A low-space notification contains, at minimum, the monitored volume name, current available space, and configured
   low-space threshold.
6. The app enters the suppressed state only after the system accepts the notification request for submission, and it
   submits at most one request for that transition.
7. Focus modes or system notification settings may prevent display after submission. The episode remains suppressed
   because the request was accepted.
8. If permission is unavailable, the app remains armed and does not attempt delivery on every check. A later explicit
   grant can make the permission-triggered check eligible to submit.
9. If an authorized notification request fails to submit, the app remains armed, exposes the failure, and may retry on
   a later check.
10. Activating a notification opens or focuses the single DiskMeerkat status window. V1 has no notification button or
    in-app action that opens system storage management.

### Application Lifecycle and Launch at Login

1. DiskMeerkat is a menu-bar-only app using `LSUIElement`; it has no normal Dock or application-switcher icon.
2. Monitoring runs for the lifetime of the app process. Closing the menu popover, Settings, or status window does not
   stop it. Choosing Quit does.
3. On first run, the app opens one status/onboarding window that identifies the monitored volume and defaults. The user
   can dismiss it without granting notification permission, and it is not shown automatically on later launches.
4. At most one status window exists. First-run presentation, a user request to show status, and notification activation
   reuse and focus that window.
5. Launch at login is an explicit opt-in using the main application's `SMAppService` and is off by default.
6. The app presents the actual launch-at-login state, including enabled, disabled, approval-required or denied, changed
   outside the app, and operation-failure states. A failed change does not make the UI claim the requested state took
   effect and does not stop monitoring.

## User-visible Status

The app makes monitoring understandable without logs. Its UI shows:

- Whether monitoring is active or a check is in progress.
- The startup volume name.
- The latest successfully measured available space, if any.
- The configured threshold and interval.
- The time of the latest successful check and the next scheduled check.
- Current disk-read, persistence, notification-permission, notification-submission, or launch-at-login problems.

The UI describes outcomes rather than requiring users to understand the internal `armed` and `suppressed` names. A
notification failure must not be presented as if disk monitoring itself stopped.

## Reliability and Privacy Requirements

- Monitoring uses negligible CPU while waiting between checks.
- Checks, persistence, and notification submission do not block the main UI thread.
- Timer replacement, wake, user actions, permission changes, and configuration changes do not create overlapping
  checks.
- Transient disk, persistence, notification, or login-item errors do not crash the app.
- Disk capacity, configuration, suppression state, and volume names remain on the device.
- The app does not upload capacity values, volume names, configuration, or monitoring history.

## Acceptance Criteria

Unless a scenario states otherwise, the threshold is `100 GB`.

1. **Space remains healthy**
   - Checks report `120 GB`, `110 GB`, and `100 GB`.
   - No notification is submitted.
   - Notification state remains armed.

2. **Space becomes low**
   - Notification state is armed and authorization is available.
   - A check reports `99 GB` and the notification request is accepted for submission.
   - Exactly one notification request is submitted.
   - Notification state becomes suppressed and is persisted.

3. **Space remains low**
   - Notification state is suppressed.
   - Later checks report `80 GB`, `95 GB`, and `100 GB`.
   - No additional notification is submitted.
   - Notification state remains suppressed.

4. **Space recovers**
   - Notification state is suppressed.
   - A check reports `101 GB`.
   - No notification is submitted.
   - Notification state becomes armed and is persisted.

5. **Space becomes low again after recovery**
   - A recovery check already rearmed notifications.
   - A later check reports `99 GB` and submission succeeds.
   - Exactly one new notification request is submitted.
   - Notification state becomes suppressed again.

6. **App restarts during a low-space episode**
   - Notification state was persisted as suppressed.
   - The first check after restart reports `90 GB`.
   - No additional notification is submitted.

7. **A disk check fails**
   - Reading `volumeAvailableCapacityForImportantUsage` throws, is missing, or is negative.
   - No low-space notification is submitted, no zero value is fabricated, and notification state is unchanged.
   - The UI exposes the failure and a later check retries normally.

8. **Valid settings are saved**
   - The user saves a supported threshold and interval.
   - Exact bytes and the selected preset are persisted, the old schedule is cancelled, and one immediate check is
     requested.
   - If a check is active, the save contributes at most one coalesced follow-up; no duplicate loop remains.
   - The next interval is scheduled from completion and notification state changes only through the normal transition.

9. **Invalid settings remain drafts**
   - The threshold is empty, fractional, below 1 GB, or above 1 PB, or the interval is unsupported.
   - Inline validation identifies the problem.
   - Persisted settings, the active schedule, and notification state are unchanged, and no check is requested.

10. **A manual check is requested**
    - `Check Now` is enabled while idle and disabled while a check is active.
    - An idle request starts one check through the normal path.
    - A request that races with active work produces at most one coalesced follow-up, never an overlapping read.

11. **The app wakes after missed intervals**
    - Several intervals pass while the Mac sleeps.
    - Wake requests at most one immediate check and no catch-up burst.
    - The next interval is scheduled from completion of the resulting serialized work.

12. **Notification permission is denied**
    - No prompt appears on launch or during background checks.
    - The user explicitly selects `Enable Notifications` and denies the system request.
    - The UI explains that notifications are unavailable, disk monitoring continues, and no repeated prompt occurs.

13. **Notification permission is granted**
    - The user explicitly selects `Enable Notifications` and grants the system request.
    - Exactly one immediate check is requested through the coalescing path.
    - If the app is armed and the reading is low, normal submission and suppression rules apply.

14. **Notification submission fails**
    - Authorization is available, the app is armed, and a check reports `99 GB`.
    - The system rejects the notification request.
    - State remains armed, the UI exposes a retryable delivery failure, and a later check may retry.

15. **A notification is activated**
    - The status window is closed or already open.
    - Activating the notification opens or focuses the one status window without creating another monitoring runtime.
    - No storage-management action is offered.

16. **First-run status is dismissed**
    - A fresh installation opens one status/onboarding window and does not prompt automatically for notifications.
    - The user dismisses it without granting permission; monitoring continues.
    - A later launch does not reopen onboarding automatically, but status remains available from the menu bar.

17. **Launch at login cannot match the requested state**
    - Registration requires approval, is denied, fails, or was changed outside the app.
    - The UI presents the actual state and a useful next action or error instead of showing a false successful toggle.
    - Monitoring in the current process continues.

18. **Windows close and the app quits**
    - Closing Settings, status, or the menu popover leaves scheduled monitoring active.
    - Choosing Quit cancels scheduled and pending work.
    - A late result after shutdown cannot mutate persisted or presented state.

19. **Capacity is near the threshold rounding boundary**
    - Exact available bytes are strictly below or above the exact threshold while ordinary display rounding would make
      the values appear equal.
    - The app adds precision or an explicit qualifier so the displayed relationship agrees with the comparison.

20. **The volume name is unavailable**
    - The startup-volume capacity is valid but the system returns no usable volume name.
    - The check succeeds, status and notification content use the localized `Startup Disk` fallback, and notification
      transitions continue normally.

21. **A persistence write fails**
    - A configuration write failure leaves the prior committed settings and schedule active, keeps the draft visible,
      reports the error, and requests no settings-triggered check.
    - If a notification request was accepted before suppression persistence fails, the current process stays
      suppressed, reports and retries the write, and does not resubmit for later low readings in that process.
    - Tests cover the documented non-atomic termination window between external submission and local persistence.

## Testing Strategy

Follow the repository-wide unit, integration, then UI test priority in the
[Development Guide](development.md#testing-strategy). The following expectations are specific to disk-space
monitoring.

### Unit Tests

Unit-test configuration validation, decimal-byte conversion and formatting, and notification transitions with:

- Values below, equal to, and above the threshold.
- Repeated low values after a notification.
- Recovery followed by another low-space episode.
- Failed and invalid readings.
- Restored persisted state.
- Threshold and interval changes.
- Boundary values from 1 GB through 1 PB and near-rounding byte values.
- Missing volume-name fallback and persistence-failure transitions.

Use controllable time and injected effects instead of real waits.

### Integration Tests

Integration-test the monitoring runtime with controlled implementations of:

- Startup-volume capacity reading.
- Versioned configuration and state persistence.
- Persistence write failures and the notification-submission durability boundary.
- Notification authorization and submission.
- Scheduling, coalescing, wake, settings, permission, and shutdown behavior.
- Launch-at-login state mapping without changing the test machine's login items.

Verify observable state, persisted values, deadlines, and notification requests rather than private method calls.

### UI Tests

Reserve UI tests for critical behavior that cannot be covered below the app boundary, such as first-run and singleton
window routing, menu-bar access, saving Settings, permission-problem presentation, and notification activation. Do not
use UI tests to duplicate pure state, validation, or scheduling coverage.

## Engineering Constraints

Follow the [package-first architecture](development.md#package-first-architecture): monitoring rules, scheduling,
configuration, persistence interfaces, presentation, and notification decisions belong in `Packages/`. The thin Xcode
app shell owns scene declarations, target settings such as `LSUIElement`, notification launch routing, and production
dependency composition. Disk, notification, clock, wake, persistence, wall-time, and login-item effects use injected
package-facing interfaces so tests remain deterministic.
