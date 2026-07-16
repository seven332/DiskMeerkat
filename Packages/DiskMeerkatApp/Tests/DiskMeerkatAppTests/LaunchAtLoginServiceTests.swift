import ServiceManagement
import XCTest

@testable import DiskMeerkatApp

final class LaunchAtLoginServiceTests: XCTestCase {
    func testSystemStatusMappingCoversEveryMainAppStatus() {
        XCTAssertEqual(SystemMainAppServiceClient.map(.notRegistered), .disabled)
        XCTAssertEqual(SystemMainAppServiceClient.map(.enabled), .enabled)
        XCTAssertEqual(SystemMainAppServiceClient.map(.requiresApproval), .requiresApproval)
        XCTAssertEqual(SystemMainAppServiceClient.map(.notFound), .unavailable)
    }

    func testInitializationAndInitialRefreshNeverChangeRegistration() async {
        let client = RecordingMainAppServiceClient(states: [.disabled])
        let service = MainAppLaunchAtLoginService(client: client)

        var calls = await client.calls()
        XCTAssertEqual(calls, .zero)

        let snapshot = await service.refresh()
        calls = await client.calls()

        XCTAssertEqual(snapshot, LaunchAtLoginSnapshot(actualState: .disabled, problem: nil))
        XCTAssertEqual(calls, MainAppServiceCalls(status: 1, register: 0, unregister: 0, settings: 0))
    }

    func testRefreshReportsAChangeAfterTheInitialObservation() async {
        let client = RecordingMainAppServiceClient(states: [.disabled, .enabled, .enabled])
        let service = MainAppLaunchAtLoginService(client: client)

        let initial = await service.refresh()
        let changed = await service.refresh()
        let stable = await service.refresh()

        XCTAssertEqual(initial, LaunchAtLoginSnapshot(actualState: .disabled, problem: nil))
        XCTAssertEqual(
            changed,
            LaunchAtLoginSnapshot(actualState: .enabled, problem: .changedExternally)
        )
        XCTAssertEqual(stable, LaunchAtLoginSnapshot(actualState: .enabled, problem: nil))
    }

    func testEnableRegistersDisabledServiceAndReturnsRefreshedActualState() async {
        let client = RecordingMainAppServiceClient(states: [.disabled, .enabled, .enabled])
        let service = MainAppLaunchAtLoginService(client: client)

        let result = await service.setEnabled(true)
        let refresh = await service.refresh()
        let calls = await client.calls()

        XCTAssertEqual(result, LaunchAtLoginSnapshot(actualState: .enabled, problem: nil))
        XCTAssertEqual(refresh, LaunchAtLoginSnapshot(actualState: .enabled, problem: nil))
        XCTAssertEqual(calls, MainAppServiceCalls(status: 3, register: 1, unregister: 0, settings: 0))
    }

    func testEnablePreservesApprovalRequiredAsTruthfulAcceptedState() async {
        let client = RecordingMainAppServiceClient(states: [.disabled, .requiresApproval])
        let service = MainAppLaunchAtLoginService(client: client)

        let result = await service.setEnabled(true)
        let calls = await client.calls()

        XCTAssertEqual(
            result,
            LaunchAtLoginSnapshot(actualState: .requiresApproval, problem: nil)
        )
        XCTAssertEqual(calls.register, 1)
        XCTAssertEqual(calls.status, 2)
    }

    func testAlreadyEnabledAndApprovalRequiredRequestsAreIdempotent() async {
        for state in [LaunchAtLoginActualState.enabled, .requiresApproval] {
            let client = RecordingMainAppServiceClient(states: [state])
            let service = MainAppLaunchAtLoginService(client: client)

            let result = await service.setEnabled(true)
            let calls = await client.calls()

            XCTAssertEqual(result, LaunchAtLoginSnapshot(actualState: state, problem: nil))
            XCTAssertEqual(calls.register, 0)
            XCTAssertEqual(calls.unregister, 0)
            XCTAssertEqual(calls.status, 1)
        }
    }

    func testDisableUnregistersEnabledAndApprovalRequiredServices() async {
        for state in [LaunchAtLoginActualState.enabled, .requiresApproval] {
            let client = RecordingMainAppServiceClient(states: [state, .disabled])
            let service = MainAppLaunchAtLoginService(client: client)

            let result = await service.setEnabled(false)
            let calls = await client.calls()

            XCTAssertEqual(result, LaunchAtLoginSnapshot(actualState: .disabled, problem: nil))
            XCTAssertEqual(calls.register, 0)
            XCTAssertEqual(calls.unregister, 1)
            XCTAssertEqual(calls.status, 2)
        }
    }

    func testThrownMutationsReturnRefreshedActualStateAndScopedFailure() async {
        let enableClient = RecordingMainAppServiceClient(
            states: [.disabled, .disabled],
            registerThrows: true
        )
        let enableService = MainAppLaunchAtLoginService(client: enableClient)
        let enableResult = await enableService.setEnabled(true)
        let enableCalls = await enableClient.calls()

        XCTAssertEqual(
            enableResult,
            LaunchAtLoginSnapshot(actualState: .disabled, problem: .enableFailed)
        )
        XCTAssertEqual(enableCalls.status, 2)

        let disableClient = RecordingMainAppServiceClient(
            states: [.enabled, .enabled],
            unregisterThrows: true
        )
        let disableService = MainAppLaunchAtLoginService(client: disableClient)
        let disableResult = await disableService.setEnabled(false)
        let disableCalls = await disableClient.calls()

        XCTAssertEqual(
            disableResult,
            LaunchAtLoginSnapshot(actualState: .enabled, problem: .disableFailed)
        )
        XCTAssertEqual(disableCalls.status, 2)
    }

    func testSilentMismatchAndUnavailableStateNeverClaimSuccess() async {
        let mismatchClient = RecordingMainAppServiceClient(states: [.disabled, .disabled])
        let mismatchService = MainAppLaunchAtLoginService(client: mismatchClient)
        let mismatch = await mismatchService.setEnabled(true)

        XCTAssertEqual(
            mismatch,
            LaunchAtLoginSnapshot(actualState: .disabled, problem: .enableFailed)
        )

        let unavailableClient = RecordingMainAppServiceClient(states: [.unavailable])
        let unavailableService = MainAppLaunchAtLoginService(client: unavailableClient)
        let unavailable = await unavailableService.setEnabled(true)
        let unavailableCalls = await unavailableClient.calls()

        XCTAssertEqual(
            unavailable,
            LaunchAtLoginSnapshot(actualState: .unavailable, problem: .enableFailed)
        )
        XCTAssertEqual(unavailableCalls.register, 0)
        XCTAssertEqual(unavailableCalls.status, 1)
    }

    func testDisabledRequestIsIdempotentAndUnavailableDisableIsScoped() async {
        let disabledClient = RecordingMainAppServiceClient(states: [.disabled])
        let disabledService = MainAppLaunchAtLoginService(client: disabledClient)
        let disabled = await disabledService.setEnabled(false)
        let disabledCalls = await disabledClient.calls()

        XCTAssertEqual(disabled, LaunchAtLoginSnapshot(actualState: .disabled, problem: nil))
        XCTAssertEqual(disabledCalls.unregister, 0)

        let unavailableClient = RecordingMainAppServiceClient(states: [.unavailable])
        let unavailableService = MainAppLaunchAtLoginService(client: unavailableClient)
        let unavailable = await unavailableService.setEnabled(false)

        XCTAssertEqual(
            unavailable,
            LaunchAtLoginSnapshot(actualState: .unavailable, problem: .disableFailed)
        )
    }

    func testOpenSystemSettingsRoutesThroughInjectedClient() async {
        let client = RecordingMainAppServiceClient(states: [.disabled])
        let service = MainAppLaunchAtLoginService(client: client)

        await service.openSystemSettings()
        let calls = await client.calls()

        XCTAssertEqual(calls.settings, 1)
        XCTAssertEqual(calls.status, 0)
        XCTAssertEqual(calls.register, 0)
        XCTAssertEqual(calls.unregister, 0)
    }
}

private enum TestMainAppServiceError: Error {
    case expectedFailure
}

private struct MainAppServiceCalls: Equatable, Sendable {
    static let zero = MainAppServiceCalls(status: 0, register: 0, unregister: 0, settings: 0)

    let status: Int
    let register: Int
    let unregister: Int
    let settings: Int
}

private actor RecordingMainAppServiceClient: MainAppServiceClient {
    private var states: [LaunchAtLoginActualState]
    private var lastState: LaunchAtLoginActualState
    private let registerThrows: Bool
    private let unregisterThrows: Bool
    private var statusCallCount = 0
    private var registerCallCount = 0
    private var unregisterCallCount = 0
    private var settingsCallCount = 0

    init(
        states: [LaunchAtLoginActualState],
        registerThrows: Bool = false,
        unregisterThrows: Bool = false
    ) {
        precondition(!states.isEmpty)
        self.states = states
        lastState = states.last!
        self.registerThrows = registerThrows
        self.unregisterThrows = unregisterThrows
    }

    func actualState() async -> LaunchAtLoginActualState {
        statusCallCount += 1
        if !states.isEmpty {
            lastState = states.removeFirst()
        }
        return lastState
    }

    func register() async throws {
        registerCallCount += 1
        if registerThrows {
            throw TestMainAppServiceError.expectedFailure
        }
    }

    func unregister() async throws {
        unregisterCallCount += 1
        if unregisterThrows {
            throw TestMainAppServiceError.expectedFailure
        }
    }

    func openSystemSettings() async {
        settingsCallCount += 1
    }

    func calls() -> MainAppServiceCalls {
        MainAppServiceCalls(
            status: statusCallCount,
            register: registerCallCount,
            unregister: unregisterCallCount,
            settings: settingsCallCount
        )
    }
}
