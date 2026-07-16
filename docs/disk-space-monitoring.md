# Disk Space Monitoring Requirements

## Status

Draft for product review.

## Summary

DiskMeerkat monitors the available space on a disk at a configurable interval. When the available space falls below a configurable threshold, the app sends a notification.

The app must not repeat the notification while the disk remains at or below the threshold. A new notification becomes eligible only after a successful check observes that the available space has risen above the threshold and a later check observes that it has fallen below the threshold again.

## Goals

- Detect low disk space without requiring the user to check manually.
- Let the user configure the check interval and low-space threshold.
- Send one useful notification for each distinct low-space episode.
- Avoid repeated notifications while the disk remains low on space.
- Preserve monitoring configuration and notification suppression across app restarts.

## Non-goals

The first version does not need to:

- Delete files or free disk space automatically.
- Recommend files for deletion.
- Predict when the disk will become full.
- Send a notification when space recovers.
- Maintain a history or chart of disk usage.
- Monitor remote or network volumes.

Support for monitoring multiple local volumes remains a product decision. This document initially assumes one monitored volume.

## Terminology

- **Monitored volume:** The disk volume whose available space is checked.
- **Available space:** The capacity value used consistently for comparisons and user-visible messages.
- **Check interval:** The configured duration between scheduled checks.
- **Low-space threshold:** The configured capacity below which a notification is eligible.
- **Armed:** A low-space notification may be sent when the next successful check is below the threshold.
- **Suppressed:** A low-space notification has already been sent and another must not be sent until recovery is observed.
- **Low-space episode:** The period beginning when an armed check first observes space below the threshold and ending when a later check observes space above the threshold.

## Functional Requirements

### Configuration

1. The user can configure the check interval.
2. The user can configure the low-space threshold.
3. Both values must be positive and within supported limits.
4. Invalid values must not replace the last valid configuration.
5. Configuration changes take effect without restarting the app.
6. The app persists valid configuration across launches.
7. The UI displays capacity values with a clear unit and uses the same interpretation when comparing the measured space with the threshold.

The default values, supported ranges, capacity unit, and whether percentage-based thresholds are supported are open product decisions.

### Scheduling and Disk Checks

1. The app performs a check when monitoring starts, then continues at the configured interval.
2. Only one disk-space check may be active at a time.
3. A changed interval replaces the existing schedule rather than creating an additional timer.
4. Missed intervals caused by sleep, suspension, or the app not running must not cause a burst of catch-up checks.
5. After the app resumes, it performs at most one immediate check and then continues on the configured schedule.
6. Each successful check returns a non-negative available-space value for the monitored volume.
7. A failed or invalid disk-space read must not be treated as zero available space.
8. A failed check must not send a low-space notification or change the notification state. The app retries on a later scheduled check.

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

This behavior ensures that remaining below the threshold produces only one notification after a request has been submitted successfully. After recovery is observed, a later drop below the threshold starts a new low-space episode and may produce one new notification.

### State Persistence and Configuration Changes

1. The app persists whether notifications are armed or suppressed.
2. Restarting the app while notification state is suppressed must not produce another notification merely because the disk is still low on space.
3. On the first successful check after launch, the app evaluates the persisted state using the normal transition table.
4. If the persisted state is suppressed and the first check is above the threshold, notifications become armed again without sending a recovery notification.
5. A threshold change is evaluated against the next successful disk-space reading using the same transition table.
6. Lowering the threshold may rearm notifications when the current available space is above the new threshold.
7. Raising the threshold may make an armed low-space notification eligible on the next successful check.
8. Changing the interval must not change the armed or suppressed state.

Persisting the suppression state favors avoiding duplicate notifications. If the app was not running, it cannot infer whether the disk briefly recovered and became low again during that time.

### Notification Delivery

1. The app requests notification authorization before relying on notifications for monitoring.
2. The app clearly indicates when notification permission is denied or unavailable.
3. The app must not repeatedly prompt for permission on every disk-space check.
4. A low-space notification includes, at minimum:
   - The monitored volume name.
   - The currently available space.
   - The configured low-space threshold.
5. The app enters the suppressed state only after successfully submitting a notification request, and it submits at most one request for that transition.
6. System behavior such as Focus modes or notification settings may prevent the notification from being displayed. Once the app successfully submits the notification request, it still treats the low-space episode as suppressed to avoid repeated requests.
7. If notification authorization is not available, the app keeps monitoring, remains armed, and exposes the permission problem in its UI. It must not request authorization or attempt delivery on every check. Granting permission while the disk is still low allows the next successful armed check to submit the notification.
8. If an authorized notification request fails to submit, the app remains armed and may retry on a later scheduled check.

## User-visible Status

The app should make the current monitoring status understandable without requiring logs. The UI should show:

- Whether monitoring is active.
- The monitored volume.
- The latest successfully measured available space.
- The configured threshold and interval.
- The time of the latest successful check.
- Any current disk-read or notification-permission problem.

Displaying whether notification state is armed or suppressed is optional, but the product should avoid presenting a repeated-notification failure as if monitoring had stopped.

## Reliability and Privacy Requirements

- Monitoring should use negligible CPU while waiting between checks.
- Checks and notifications must not block the main UI thread.
- Timer replacement, app resume, and configuration changes must not create overlapping checks.
- A transient read or notification error must not crash the app.
- Disk capacity measurements and configuration remain on the device.
- The feature must not upload volume names, capacity values, or monitoring history.

## Acceptance Criteria

Given a threshold of `100 GB`, the following scenarios must hold:

1. **Space remains healthy**
   - Checks report `120 GB`, `110 GB`, and `100 GB`.
   - No notification is sent.
   - Notification state remains armed.

2. **Space becomes low**
   - Notification state is armed.
   - A check reports `99 GB`.
   - Exactly one notification request is submitted.
   - Notification state becomes suppressed.

3. **Space remains low**
   - Notification state is suppressed.
   - Later checks report `80 GB`, `95 GB`, and `100 GB`.
   - No additional notification is submitted.
   - Notification state remains suppressed.

4. **Space recovers**
   - Notification state is suppressed.
   - A check reports `101 GB`.
   - No notification is submitted.
   - Notification state becomes armed.

5. **Space becomes low again after recovery**
   - A recovery check has already rearmed notifications.
   - A later check reports `99 GB`.
   - Exactly one new notification request is submitted.
   - Notification state becomes suppressed again.

6. **App restarts during a low-space episode**
   - Notification state was persisted as suppressed.
   - The first check after restart reports `90 GB`.
   - No additional notification is submitted.

7. **A disk check fails**
   - A check returns an error or invalid value.
   - No low-space notification is submitted.
   - Notification state is unchanged.
   - A later scheduled check retries normally.

8. **The interval changes**
   - The user saves a new valid interval.
   - The old schedule is cancelled and replaced.
   - No overlapping or duplicate monitoring loop remains active.
   - Notification state is unchanged.

9. **Notification permission is denied**
   - The app does not repeatedly request permission during checks.
   - The UI explains that notifications cannot currently be delivered.
   - Disk monitoring continues without crashing.

## Testing Strategy

Follow the repository-wide unit, integration, then UI test priority.

### Unit Tests

Unit-test the notification state machine with sequences of available-space values, including:

- Values below, equal to, and above the threshold.
- Repeated low values after a notification.
- Recovery followed by another low-space episode.
- Failed and invalid readings.
- Restored persisted state.
- Threshold and interval changes.

Use a controllable clock or scheduler abstraction instead of real waits.

### Integration Tests

Integration-test the monitoring coordinator with controlled implementations of:

- Disk-capacity reading.
- Configuration persistence.
- Notification authorization and submission.
- Timer replacement and resume behavior.

Verify observable state and notification requests rather than internal method calls.

### UI Tests

Reserve UI tests for a small number of critical flows that cannot be covered below the UI boundary, such as saving settings, displaying permission problems, and confirming that the app shell presents the monitoring status.

## Engineering Constraints

- Monitoring rules, scheduling, configuration, and testable notification decisions belong in `Packages/`.
- The Xcode application target remains a thin shell and contains only app lifecycle, notification-system wiring, entitlements, and other target-specific integration that cannot live cleanly in a package.
- System disk and notification APIs should be accessed behind package-facing interfaces so that the state machine can be unit-tested deterministically.

## Open Product Decisions

Before implementation, confirm:

1. Which volume is monitored by default: the startup volume, the volume containing the user's home directory, or a user-selected volume?
2. Does the first version monitor exactly one volume, or can the user configure multiple local volumes independently?
3. What are the default, minimum, and maximum check intervals?
4. What is the default low-space threshold?
5. Is the threshold an absolute capacity, a percentage, or either?
6. Are capacity units decimal (`GB`) or binary (`GiB`)?
7. Which macOS available-capacity definition is used, especially regarding purgeable space?
8. Must monitoring continue when the main window is closed, and should the app support launching at login?
9. Should saving settings trigger an immediate check, or should changes apply at the next scheduled check?
10. Should the notification include an action that opens DiskMeerkat or a system storage-management view?
