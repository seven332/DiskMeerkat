import Foundation
import UserNotifications
import XCTest

@testable import DiskMeerkatApp

final class UserNotificationsMonitoringServiceTests: XCTestCase {
    func testSystemAuthorizationStatusMappingCoversSupportedMacOSStates() {
        XCTAssertEqual(
            SystemUserNotificationCenterClient.map(.notDetermined),
            .notDetermined
        )
        XCTAssertEqual(SystemUserNotificationCenterClient.map(.denied), .denied)
        XCTAssertEqual(SystemUserNotificationCenterClient.map(.authorized), .authorized)
        XCTAssertEqual(SystemUserNotificationCenterClient.map(.provisional), .provisional)
    }

    func testReadingAuthorizationMapsEveryDomainStateWithoutRequestingPermission() async throws {
        let mappings: [(UserNotificationAuthorizationStatus, NotificationAuthorizationState)] = [
            (.notDetermined, .notDetermined),
            (.denied, .denied),
            (.authorized, .authorized),
            (.provisional, .authorized),
            (.unavailable, .unavailable),
        ]

        for (clientState, expectedState) in mappings {
            let client = RecordingUserNotificationCenterClient(status: clientState)
            let service = makeService(client: client)

            let state = try await service.authorizationState()
            let calls = await client.calls()

            XCTAssertEqual(state, expectedState)
            XCTAssertEqual(calls.status, 1)
            XCTAssertEqual(calls.request, 0)
            XCTAssertEqual(calls.add, 0)
        }
    }

    func testAuthorizationIsRequestedOnlyByExplicitRequestMethod() async throws {
        let client = RecordingUserNotificationCenterClient(
            status: .notDetermined,
            requestedStatus: .provisional
        )
        let service = makeService(client: client)

        _ = try await service.authorizationState()
        var calls = await client.calls()
        XCTAssertEqual(calls.request, 0)

        let requestedState = try await service.requestAuthorization()
        calls = await client.calls()
        XCTAssertEqual(requestedState, .authorized)
        XCTAssertEqual(calls.status, 1)
        XCTAssertEqual(calls.request, 1)
    }

    func testAuthorizationAndStatusErrorsPropagate() async {
        let statusClient = RecordingUserNotificationCenterClient(
            status: .notDetermined,
            failures: [.status]
        )
        let statusService = makeService(client: statusClient)
        await assertThrows {
            _ = try await statusService.authorizationState()
        }

        let requestClient = RecordingUserNotificationCenterClient(
            status: .notDetermined,
            failures: [.request]
        )
        let requestService = makeService(client: requestClient)
        await assertThrows {
            _ = try await requestService.requestAuthorization()
        }
    }

    func testSubmissionUsesStableIdentityAndApprovedNamedVolumeContent() async throws {
        let client = RecordingUserNotificationCenterClient(status: .authorized)
        let service = makeService(client: client)
        let firstCandidate = try notificationCandidate(
            availableBytes: 18_400_000_000,
            thresholdGigabytes: 20,
            volumeName: "Macintosh HD"
        )
        let secondCandidate = try notificationCandidate(
            availableBytes: 17_000_000_000,
            thresholdGigabytes: 20,
            volumeName: "Macintosh HD"
        )

        try await service.submit(firstCandidate)
        try await service.submit(secondCandidate)
        let requests = await client.requests()

        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(
            requests.map(\.identifier),
            [
                UserNotificationsMonitoringService.lowSpaceRequestIdentifier,
                UserNotificationsMonitoringService.lowSpaceRequestIdentifier,
            ])
        XCTAssertEqual(requests[0].title, "Disk space is low")
        XCTAssertEqual(
            requests[0].body,
            "Macintosh HD has 18.4 GB available, below your 20 GB limit."
        )
        XCTAssertTrue(requests[0].usesDefaultSound)
    }

    func testSubmissionUsesFallbackNameAndLocaleAwareThresholdSafeValues() async throws {
        let client = RecordingUserNotificationCenterClient(status: .authorized)
        let service = UserNotificationsMonitoringService(
            client: client,
            locale: Locale(identifier: "de_DE"),
            notificationTitle: "Disk space is low",
            startupDiskName: "Startup Disk"
        )
        let candidate = try notificationCandidate(
            availableBytes: 999_999_999_999,
            thresholdGigabytes: 1_000,
            volumeName: nil
        )

        try await service.submit(candidate)
        let requests = await client.requests()
        let request = try XCTUnwrap(requests.first)

        XCTAssertEqual(
            request.body,
            "Startup Disk has 999,999999999 GB available, below your 1.000 GB limit."
        )
    }

    func testSubmissionErrorPropagatesAfterRecordingStableRequest() async throws {
        let client = RecordingUserNotificationCenterClient(
            status: .authorized,
            failures: [.add]
        )
        let service = makeService(client: client)
        let candidate = try notificationCandidate(
            availableBytes: 18_000_000_000,
            thresholdGigabytes: 20,
            volumeName: "Macintosh HD"
        )

        await assertThrows {
            try await service.submit(candidate)
        }
        let requests = await client.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(
            requests[0].identifier,
            UserNotificationsMonitoringService.lowSpaceRequestIdentifier
        )
    }

    private func makeService(
        client: RecordingUserNotificationCenterClient
    ) -> UserNotificationsMonitoringService {
        UserNotificationsMonitoringService(
            client: client,
            locale: Locale(identifier: "en_US_POSIX"),
            notificationTitle: "Disk space is low",
            startupDiskName: "Startup Disk"
        )
    }

    private func notificationCandidate(
        availableBytes: Int64,
        thresholdGigabytes: Int64,
        volumeName: String?
    ) throws -> LowSpaceNotificationCandidate {
        let threshold = try LowSpaceThreshold(gigabytes: thresholdGigabytes)
        let evaluation = LowSpaceNotificationPolicy.evaluate(
            reading: .available(
                StartupVolumeSnapshot(
                    availableCapacity: try DiskCapacity(bytes: availableBytes),
                    volumeName: volumeName
                )
            ),
            threshold: threshold,
            episodeState: .armed
        )
        guard case .submit(let candidate) = evaluation.notificationDirective else {
            throw TestNotificationClientError.candidateNotEligible
        }
        return candidate
    }

    private func assertThrows(
        _ operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected operation to throw", file: file, line: line)
        } catch {
            // Any system-client error must pass through the adapter.
        }
    }
}

private enum TestNotificationClientError: Error {
    case expectedFailure
    case candidateNotEligible
}

private enum NotificationClientOperation: Hashable, Sendable {
    case status
    case request
    case add
}

private struct NotificationClientCalls: Equatable, Sendable {
    let status: Int
    let request: Int
    let add: Int
}

private actor RecordingUserNotificationCenterClient: UserNotificationCenterClient {
    private let status: UserNotificationAuthorizationStatus
    private let requestedStatus: UserNotificationAuthorizationStatus
    private let failures: Set<NotificationClientOperation>
    private var statusCallCount = 0
    private var requestCallCount = 0
    private var submittedRequests: [UserNotificationRequestDescriptor] = []

    init(
        status: UserNotificationAuthorizationStatus,
        requestedStatus: UserNotificationAuthorizationStatus? = nil,
        failures: Set<NotificationClientOperation> = []
    ) {
        self.status = status
        self.requestedStatus = requestedStatus ?? status
        self.failures = failures
    }

    func authorizationStatus() async throws -> UserNotificationAuthorizationStatus {
        statusCallCount += 1
        if failures.contains(.status) {
            throw TestNotificationClientError.expectedFailure
        }
        return status
    }

    func requestAuthorization() async throws -> UserNotificationAuthorizationStatus {
        requestCallCount += 1
        if failures.contains(.request) {
            throw TestNotificationClientError.expectedFailure
        }
        return requestedStatus
    }

    func add(_ request: UserNotificationRequestDescriptor) async throws {
        submittedRequests.append(request)
        if failures.contains(.add) {
            throw TestNotificationClientError.expectedFailure
        }
    }

    func calls() -> NotificationClientCalls {
        NotificationClientCalls(
            status: statusCallCount,
            request: requestCallCount,
            add: submittedRequests.count
        )
    }

    func requests() -> [UserNotificationRequestDescriptor] {
        submittedRequests
    }
}
