# DiskMeerkat V1 Acceptance

## Status and Scope

DiskMeerkat V1 is delivered. The [monitoring requirements](disk-space-monitoring.md) remain authoritative for product
behavior, and the [UI design](ui-design.md) remains authoritative for presentation. This document records verification
evidence; it does not repeat or redefine those decisions.

Every numbered item from the product documents appears below. A numeric range means the same evidence applies to each
item in that range. XCTest names identify the observable behavior that supplies the evidence.

## Evidence Catalog

| ID | Layer | Location |
| --- | --- | --- |
| `CFG` | Unit | [MonitoringConfigurationTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/MonitoringConfigurationTests.swift) |
| `POL` | Unit | [LowSpaceNotificationPolicyTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/LowSpaceNotificationPolicyTests.swift) |
| `FMT` | Unit | [DiskCapacityFormatterTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/DiskCapacityFormatterTests.swift) |
| `DISK` | Controlled integration | [StartupVolumeReaderTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/StartupVolumeReaderTests.swift) |
| `STORE` | Controlled integration | [MonitoringStateRepositoryTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/MonitoringStateRepositoryTests.swift) |
| `RUN` | Controlled integration | [MonitoringRuntimeTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/MonitoringRuntimeTests.swift) |
| `NOTIFY` | Adapter | [UserNotificationsMonitoringServiceTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/UserNotificationsMonitoringServiceTests.swift) |
| `WAKE` | Adapter | [WorkspaceWakeEventSourceTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/WorkspaceWakeEventSourceTests.swift) |
| `TIME` | Adapter | [SystemMonitoringTimeTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/SystemMonitoringTimeTests.swift) |
| `LOGIN` | Adapter | [LaunchAtLoginServiceTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/LaunchAtLoginServiceTests.swift) |
| `DRAFT` | Unit | [MonitoringSettingsDraftTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/MonitoringSettingsDraftTests.swift) |
| `STATE` | Unit | [MonitoringPresentationStateTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/MonitoringPresentationStateTests.swift) |
| `MODEL` | Unit/integration | [DiskMeerkatPresentationModelTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/DiskMeerkatPresentationModelTests.swift) |
| `APP` | Integration | [DiskMeerkatApplicationControllerTests](../Packages/DiskMeerkatApp/Tests/DiskMeerkatAppTests/DiskMeerkatApplicationControllerTests.swift) |
| `XCUI` | App boundary | [DiskMeerkatUITests](../DiskMeerkatUITests/DiskMeerkatUITests.swift) |
| `SHELL` | Source/configuration | [`DiskMeerkat/`](../DiskMeerkat/) and the [Xcode project](../DiskMeerkat.xcodeproj/project.pbxproj) |
| `CI` | Built-product boundary | [CI workflow](../.github/workflows/ci.yml) |

## Functional Requirements

### Monitoring, Configuration, and Scheduling

| Requirement reference | Evidence |
| --- | --- |
| [Monitored volume 1–3](disk-space-monitoring.md#monitored-volume-and-available-capacity) | `DISK/testValidReadUsesStartupRootAndRequiredResourceKeys` |
| Monitored volume 4 | `DISK/testMissingAndBlankNamesRemainSuccessfulReads`, `DISK/testVolumeNameIsTrimmed`, `STATE/testMissingVolumeNameUsesTheStartupDiskFallback` |
| Monitored volume 5 | `DISK/testMissingCapacityIsUnavailableRatherThanZero`, `DISK/testNegativeCapacityIsInvalidRatherThanZero`, `DISK/testThrownResourceReadIsUnavailable` |
| Monitored volume 6 | `CFG/testDiskCapacityUsesExactComparableBytes`, `CFG/testThresholdRestoresExactWholeGigabyteBytes` |
| Monitored volume 7 | `FMT/testIncreasesPrecisionWhenDefaultRoundingWouldReachThreshold`, `FMT/testPreservesStrictRelationshipAtByteAdjacentThresholdValues` |
| [Configuration 1–4](disk-space-monitoring.md#configuration) | `CFG/testDefaultConfigurationUsesApprovedValues`, `CFG/testCheckIntervalPresetsExposeStableSecondsAndDurations`, `CFG/testThresholdAcceptsSupportedGigabyteBoundaries`, `CFG/testThresholdRestoresExactWholeGigabyteBytes` |
| Configuration 5 | `DRAFT/testBlankFractionalAndPartialInputsHaveSpecificErrors`, `DRAFT/testSupportedRangeIsValidatedBeforeBuildingConfiguration`, `MODEL/testInvalidAndUnchangedDraftsNeverInvokeSave` |
| Configuration 6 | `RUN/testConfigurationIsPersistedBeforeItAppliesAndReplacesTheSchedule` |
| Configuration 7 | `RUN/testConfigurationFailureKeepsThePreviousStateScheduleAndCheckCount`, `MODEL/testFailedSaveKeepsDraftAndExplainsThatCommittedValuesRemainActive` |
| Configuration 8 | `STORE/testStateRoundTripsExactValuesAndSurvivesRepositoryRecreation`, `RUN/testConfigurationIsPersistedBeforeItAppliesAndReplacesTheSchedule` |
| Configuration 9–10 | `POL/testThresholdChangesUseTheSameTransitionRules`, `RUN/testConfigurationCommittedDuringAReadDiscardsTheOldThresholdResult` |
| [Scheduling 1](disk-space-monitoring.md#scheduling-and-disk-checks) | `RUN/testStartRestoresSuppressionAndSchedulesFromCompletion` |
| Scheduling 2–4 | `RUN/testActiveTriggersCoalesceIntoOneFollowUpBeforeScheduling`, `RUN/testAValidScheduleFireRunsOneCheckAndCreatesOneNewWait` |
| Scheduling 5 | `RUN/testConfigurationIsPersistedBeforeItAppliesAndReplacesTheSchedule` |
| Scheduling 6–7 | `RUN/testActiveTriggersCoalesceIntoOneFollowUpBeforeScheduling`, `WAKE/testOneStreamInstallsOneObserverAndForwardsWakeEvents`, `TIME/testSuspendingSchedulerPreservesCancellation` |
| Scheduling 8 | `RUN/testDiskFailureKeepsTheLastSuccessfulVolumeAndEpisodeState` |
| Scheduling 9 | `MODEL/testCheckNowRoutesOnlyWhenRuntimeStateAllowsIt`, `RUN/testActiveTriggersCoalesceIntoOneFollowUpBeforeScheduling` |
| Scheduling 10 | `RUN/testSnapshotStreamPublishesLatestStateAndLateReadCannotMutateAfterStop`, `RUN/testAcceptedSubmissionReturningAfterStopCannotSuppressPersistOrSchedule`, `RUN/testCanceledScheduleThatReturnsLateDoesNotRunAfterStop` |

### Notification State and Persistence

The transition identifiers below follow the six rows of the
[notification-state table](disk-space-monitoring.md#notification-state), from top to bottom.

| Requirement reference | Evidence |
| --- | --- |
| Transition 1: armed, below, accepted | `POL/testArmedStateSubmitsOnlyBelowThreshold`, `POL/testSubmissionOutcomeChangesStateOnlyAfterCandidateExists` |
| Transition 2: armed, below, rejected | `POL/testSubmissionOutcomeChangesStateOnlyAfterCandidateExists`, `RUN/testSubmissionFailureStaysArmedAndRetriesOnALaterCheck` |
| Transition 3: armed, equal or above | `POL/testArmedStateSubmitsOnlyBelowThreshold` |
| Transition 4: suppressed, equal or below | `POL/testSuppressedStateRearmsOnlyAboveThreshold` |
| Transition 5: suppressed, above | `POL/testSuppressedStateRearmsOnlyAboveThreshold` |
| Transition 6: failed reading | `POL/testFailedReadingsPreserveEveryEpisodeState`, `RUN/testDiskFailureKeepsTheLastSuccessfulVolumeAndEpisodeState` |
| [Persistence 1–4](disk-space-monitoring.md#state-persistence-and-configuration-changes) | `STORE/testStateRoundTripsExactValuesAndSurvivesRepositoryRecreation`, `STORE/testEveryIntervalAndEpisodeStateRoundTrips`, `RUN/testStartRestoresSuppressionAndSchedulesFromCompletion` |
| Persistence 5–6 | `POL/testThresholdChangesUseTheSameTransitionRules`, `RUN/testConfigurationCommittedDuringAReadDiscardsTheOldThresholdResult` |
| Persistence 7 | `POL/testFailedReadingsPreserveEveryEpisodeState`, `RUN/testSubmissionFailureStaysArmedAndRetriesOnALaterCheck` |
| Persistence 8 | `STORE/testStateRoundTripsExactValuesAndSurvivesRepositoryRecreation`, `RUN/testOnboardingCompletionPersistsWithoutRequestingACheck` |
| Persistence 9 | `RUN/testConfigurationAndAcceptedSubmissionPersistTheLatestAggregateInOrder` |
| Persistence 10 | `RUN/testSuppressionPersistenceFailureNeverResubmitsAndRetriesUntilSaved` |
| Persistence 11 | `RUN/testSuppressionPersistenceFailureNeverResubmitsAndRetriesUntilSaved`, `RUN/testAcceptedSubmissionReturningAfterStopCannotSuppressPersistOrSchedule` |

### Notifications and Application Lifecycle

| Requirement reference | Evidence |
| --- | --- |
| [Authorization 1–2](disk-space-monitoring.md#notification-authorization-and-delivery) | `NOTIFY/testReadingAuthorizationMapsEveryDomainStateWithoutRequestingPermission`, `NOTIFY/testAuthorizationIsRequestedOnlyByExplicitRequestMethod`, `MODEL/testNotificationPromptIsOnlyRoutedFromEligibleExplicitAction` |
| Authorization 3 | `RUN/testDeniedPermissionDoesNotCheckAndLaterGrantCoalescesOneCheck` |
| Authorization 4 | `STATE/testEveryNotificationAuthorizationStateHasTruthfulActions`, `RUN/testStartupAuthorizationFailureDoesNotStopMonitoringAndRefreshGrantChecks` |
| Authorization 5 | `NOTIFY/testSubmissionUsesStableIdentityAndApprovedNamedVolumeContent`, `NOTIFY/testSubmissionUsesFallbackNameAndLocaleAwareThresholdSafeValues` |
| Authorization 6–8 | `RUN/testNotificationEpisodeSuppressesRearmsAndSubmitsAgain`, `RUN/testDeniedPermissionDoesNotCheckAndLaterGrantCoalescesOneCheck` |
| Authorization 9 | `NOTIFY/testSubmissionErrorPropagatesAfterRecordingStableRequest`, `RUN/testSubmissionFailureStaysArmedAndRetriesOnALaterCheck` |
| Authorization 10 | `XCUI/testNotificationActivationDuringLaunchAndWhileRunningUsesOneWindow`, `APP/testOneControllerStartsAndStopsOneRuntimeWithoutDuplicateWork` |
| [Lifecycle 1](disk-space-monitoring.md#application-lifecycle-and-launch-at-login) | `CI/Verify release app boundary` checks the built Release Info.plist and fixture isolation; `SHELL` owns `LSUIElement` |
| Lifecycle 2 | `XCUI/testFirstRunDismissalAndWindowCloseLeaveMenuAppRunning`, `XCUI/testMenuStatusSettingsValidationAndQuitShareTheAppBoundary` |
| Lifecycle 3 | `XCUI/testFirstRunDismissalAndWindowCloseLeaveMenuAppRunning`, `APP/testStatusWindowClosePersistsOnboardingWithoutRequestingPermission` |
| Lifecycle 4 | `XCUI/testNotificationActivationDuringLaunchAndWhileRunningUsesOneWindow`, `APP/testOneControllerStartsAndStopsOneRuntimeWithoutDuplicateWork` |
| Lifecycle 5 | `LOGIN/testInitializationAndInitialRefreshNeverChangeRegistration`, `LOGIN/testEnableRegistersDisabledServiceAndReturnsRefreshedActualState` |
| Lifecycle 6 | `LOGIN/testSystemStatusMappingCoversEveryMainAppStatus`, `LOGIN/testSilentMismatchAndUnavailableStateNeverClaimSuccess`, `MODEL/testLaunchAtLoginUsesReturnedActualStateAndRoutesSystemSettings` |

### Status, Reliability, Privacy, and Ownership

The status and reliability identifiers refer to bullets in document order.

| Requirement reference | Evidence |
| --- | --- |
| [User-visible status 1–4](disk-space-monitoring.md#user-visible-status) | `STATE/testStartingAndFirstRunningCheckHaveExplicitProgressCopy`, `STATE/testHealthyAndBoundaryCapacityMapToMonitoring`, `STATE/testCheckInProgressRetainsTheLastSuccessfulCapacity` |
| User-visible status 5–6 | `STATE/testStartingAndFirstRunningCheckHaveExplicitProgressCopy`, `STATE/testEverySupportedIntervalHasConciseDisplayCopy` |
| User-visible status 7 | `STATE/testDiskReadFailureKeepsLastSuccessfulValueAndAddsScopedNotice`, `STATE/testPersistenceFailuresRemainScopedAndExplainTheCommittedState`, `STATE/testEveryNotificationFailureHasAScopedNotice`, `STATE/testLaunchAtLoginPresentationUsesActualStateAndScopedProblems` |
| [Reliability/privacy 1](disk-space-monitoring.md#reliability-and-privacy-requirements) | `TIME/testSuspendingSchedulerPreservesCancellation`, `RUN/testStartRestoresSuppressionAndSchedulesFromCompletion` |
| Reliability/privacy 2 | `RUN` uses asynchronous injected effects behind one actor; package tests exercise suspended reads and writes without blocking the UI actor |
| Reliability/privacy 3 | `RUN/testActiveTriggersCoalesceIntoOneFollowUpBeforeScheduling`, `RUN/testConfigurationIsPersistedBeforeItAppliesAndReplacesTheSchedule` |
| Reliability/privacy 4 | `RUN/testDiskFailureKeepsTheLastSuccessfulVolumeAndEpisodeState`, `RUN/testSuppressionPersistenceFailureNeverResubmitsAndRetriesUntilSaved`, `LOGIN/testThrownMutationsReturnRefreshedActualStateAndScopedFailure` |
| Reliability/privacy 5–6 | `SHELL` source/dependency inspection: sandboxing is enabled, there is no network dependency or upload/history implementation, and persisted values remain local |
| [Testing strategy and engineering constraints](disk-space-monitoring.md#testing-strategy) | Evidence is concentrated in package tests; `XCUI` covers only app-bound behavior; production effects use injected package interfaces |

## Behavioral Acceptance Scenarios

| Scenario | Evidence |
| --- | --- |
| [1. Space remains healthy](disk-space-monitoring.md#acceptance-criteria) | `POL/testArmedStateSubmitsOnlyBelowThreshold` |
| 2. Space becomes low | `POL/testSubmissionOutcomeChangesStateOnlyAfterCandidateExists`, `RUN/testNotificationEpisodeSuppressesRearmsAndSubmitsAgain` |
| 3. Space remains low | `POL/testSuppressedStateRearmsOnlyAboveThreshold`, `RUN/testNotificationEpisodeSuppressesRearmsAndSubmitsAgain` |
| 4. Space recovers | `POL/testSuppressedStateRearmsOnlyAboveThreshold`, `RUN/testNotificationEpisodeSuppressesRearmsAndSubmitsAgain` |
| 5. Space becomes low again | `RUN/testNotificationEpisodeSuppressesRearmsAndSubmitsAgain` |
| 6. Relaunch during a low-space episode | `STORE/testStateRoundTripsExactValuesAndSurvivesRepositoryRecreation`, `RUN/testStartRestoresSuppressionAndSchedulesFromCompletion` |
| 7. Disk check fails | `DISK/testMissingCapacityIsUnavailableRatherThanZero`, `DISK/testNegativeCapacityIsInvalidRatherThanZero`, `DISK/testThrownResourceReadIsUnavailable`, `RUN/testDiskFailureKeepsTheLastSuccessfulVolumeAndEpisodeState` |
| 8. Valid settings are saved | `MODEL/testSuccessfulSaveRoutesValidatedConfigurationAndEndsEditing`, `RUN/testConfigurationIsPersistedBeforeItAppliesAndReplacesTheSchedule` |
| 9. Invalid settings remain drafts | `DRAFT/testBlankFractionalAndPartialInputsHaveSpecificErrors`, `MODEL/testInvalidAndUnchangedDraftsNeverInvokeSave`, `XCUI/testMenuStatusSettingsValidationAndQuitShareTheAppBoundary` |
| 10. Manual check is requested | `MODEL/testCheckNowRoutesOnlyWhenRuntimeStateAllowsIt`, `MODEL/testCheckNowPreventsDuplicateRequestsWhileSubmissionIsPending`, `RUN/testActiveTriggersCoalesceIntoOneFollowUpBeforeScheduling` |
| 11. App wakes after missed intervals | `RUN/testActiveTriggersCoalesceIntoOneFollowUpBeforeScheduling`, `WAKE/testOneStreamInstallsOneObserverAndForwardsWakeEvents`, `TIME/testSuspendingSchedulerPreservesCancellation` |
| 12. Notification permission is denied | `RUN/testDeniedPermissionDoesNotCheckAndLaterGrantCoalescesOneCheck`, `MODEL/testDeniedPermissionOpensInjectedSettingsThenRefreshes`, `XCUI/testControlledProblemFixturesRemainScoped` |
| 13. Notification permission is granted | `RUN/testDeniedPermissionDoesNotCheckAndLaterGrantCoalescesOneCheck`, `MODEL/testNotificationPromptIsOnlyRoutedFromEligibleExplicitAction` |
| 14. Notification submission fails | `RUN/testSubmissionFailureStaysArmedAndRetriesOnALaterCheck`, `STATE/testEveryNotificationFailureHasAScopedNotice` |
| 15. Notification is activated | `XCUI/testNotificationActivationDuringLaunchAndWhileRunningUsesOneWindow` |
| 16. First-run status is dismissed | `APP/testStatusWindowClosePersistsOnboardingWithoutRequestingPermission`, `XCUI/testFirstRunDismissalAndWindowCloseLeaveMenuAppRunning` |
| 17. Launch at login cannot match | `LOGIN/testSilentMismatchAndUnavailableStateNeverClaimSuccess`, `LOGIN/testThrownMutationsReturnRefreshedActualStateAndScopedFailure`, `MODEL/testLaunchAtLoginUsesReturnedActualStateAndRoutesSystemSettings` |
| 18. Windows close and app quits | `XCUI/testFirstRunDismissalAndWindowCloseLeaveMenuAppRunning`, `XCUI/testMenuStatusSettingsValidationAndQuitShareTheAppBoundary`, `RUN/testSnapshotStreamPublishesLatestStateAndLateReadCannotMutateAfterStop` |
| 19. Capacity is near rounding boundary | `FMT/testIncreasesPrecisionWhenDefaultRoundingWouldReachThreshold`, `FMT/testPreservesStrictRelationshipAtByteAdjacentThresholdValues` |
| 20. Volume name is unavailable | `DISK/testMissingAndBlankNamesRemainSuccessfulReads`, `STATE/testMissingVolumeNameUsesTheStartupDiskFallback`, `NOTIFY/testSubmissionUsesFallbackNameAndLocaleAwareThresholdSafeValues` |
| 21. Persistence write fails | `RUN/testConfigurationFailureKeepsThePreviousStateScheduleAndCheckCount`, `MODEL/testFailedSaveKeepsDraftAndExplainsThatCommittedValuesRemainActive`, `RUN/testSuppressionPersistenceFailureNeverResubmitsAndRetriesUntilSaved`, `RUN/testAcceptedSubmissionReturningAfterStopCannotSuppressPersistOrSchedule` |

## UI Design Traceability

### Presentation Sections

| UI design section | Evidence |
| --- | --- |
| [Menu bar experience](ui-design.md#menu-bar-experience) | `STATE` status mappings, package `DiskMeerkatMenuView`, and `XCUI/testMenuStatusSettingsValidationAndQuitShareTheAppBoundary` |
| [Status presentation](ui-design.md#status-presentation) | `STATE/testLowSpaceCopyReflectsDeliveryPermissionAndEpisodeOutcomes` plus scoped read, persistence, notification, and login failure tests |
| [Status and first run](ui-design.md#status-and-first-run-window) | `APP` lifecycle tests and `XCUI/testFirstRunDismissalAndWindowCloseLeaveMenuAppRunning` |
| [Settings](ui-design.md#settings-window) | `DRAFT`, `MODEL` save tests, and `XCUI/testMenuStatusSettingsValidationAndQuitShareTheAppBoundary` |
| [Notification permission](ui-design.md#notification-permission) | `NOTIFY/testAuthorizationIsRequestedOnlyByExplicitRequestMethod`, `MODEL` permission action tests, and `XCUI/testControlledProblemFixturesRemainScoped` |
| [Launch at login](ui-design.md#launch-at-login) | `LOGIN` and `MODEL` launch-at-login tests |
| [Notification content and activation](ui-design.md#notification-content-and-activation) | `NOTIFY` content tests and `XCUI/testNotificationActivationDuringLaunchAndWhileRunningUsesOneWindow` |
| [Accessibility and formatting](ui-design.md#accessibility-and-formatting) | `DRAFT/testAccessibilityIdentifiersAreStableAndUnique`, package view accessibility labels and keyboard shortcuts, `STATE/testCapacityAndConfigurationUseRequestedLocale`, and `FMT` boundary tests |
| [Architecture boundary](ui-design.md#architecture-boundary) | Reusable views/models/services are in `Packages/DiskMeerkatApp`; `SHELL` contains only scenes, lifecycle, routing, target settings, and composition |

### Interaction Acceptance

| Scenario | Evidence |
| --- | --- |
| [1. First launch](ui-design.md#interaction-acceptance) | `XCUI/testFirstRunDismissalAndWindowCloseLeaveMenuAppRunning` |
| 2. Close windows and Quit | `XCUI/testFirstRunDismissalAndWindowCloseLeaveMenuAppRunning`, `XCUI/testMenuStatusSettingsValidationAndQuitShareTheAppBoundary` |
| 3. Invalid and failed Settings drafts | `XCUI/testMenuStatusSettingsValidationAndQuitShareTheAppBoundary`, `MODEL/testFailedSaveKeepsDraftAndExplainsThatCommittedValuesRemainActive` |
| 4. In-progress presentation and Check Now | `STATE/testCheckInProgressRetainsTheLastSuccessfulCapacity`, `MODEL/testCheckNowRoutesOnlyWhenRuntimeStateAllowsIt` |
| 5. Explicit notification prompt and denial | `NOTIFY/testAuthorizationIsRequestedOnlyByExplicitRequestMethod`, `MODEL/testDeniedPermissionOpensInjectedSettingsThenRefreshes`, `XCUI/testControlledProblemFixturesRemainScoped` |
| 6. Singleton notification activation | `XCUI/testNotificationActivationDuringLaunchAndWhileRunningUsesOneWindow` |
| 7. Truthful launch-at-login state | `LOGIN/testSystemStatusMappingCoversEveryMainAppStatus`, `LOGIN/testSilentMismatchAndUnavailableStateNeverClaimSuccess`, `MODEL/testLaunchAtLoginUsesReturnedActualStateAndRoutesSystemSettings` |
| 8. Threshold-safe capacity text | `FMT/testIncreasesPrecisionWhenDefaultRoundingWouldReachThreshold`, `FMT/testPreservesStrictRelationshipAtByteAdjacentThresholdValues` |

## Built-product and Platform Verification

GitHub CI is the current-head merge gate. It runs strict formatting, all package tests, all app/UI tests using XCUI,
and a separate Release build. The Release step verifies the generated app has `LSUIElement = true` and that UI-test
fixture entry keys are absent from the executable.

Some macOS outcomes are controlled by user and system state. Before distributing a signed build, a maintainer may
also smoke-test the real notification prompt and banner, launch-at-login approval, VoiceOver labels, keyboard focus,
and larger accessibility text. These observations supplement rather than replace the deterministic adapter,
presentation, XCUI, and Release evidence above; automated verification must not change a developer's notification or
login-item settings.

Use [Local Validation](development.md#local-validation) for change-sensitive commands. Documentation-only changes do
not require unrelated tests, while this final acceptance slice deliberately runs the complete repository and Release
gate once before merge.
