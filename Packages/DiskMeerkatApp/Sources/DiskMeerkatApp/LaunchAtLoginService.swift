import ServiceManagement

enum LaunchAtLoginActualState: Equatable, Sendable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

enum LaunchAtLoginProblem: Equatable, Sendable {
    case changedExternally
    case enableFailed
    case disableFailed
}

struct LaunchAtLoginSnapshot: Equatable, Sendable {
    let actualState: LaunchAtLoginActualState
    let problem: LaunchAtLoginProblem?
}

protocol LaunchAtLoginService: Sendable {
    func refresh() async -> LaunchAtLoginSnapshot
    func setEnabled(_ isEnabled: Bool) async -> LaunchAtLoginSnapshot
    func openSystemSettings() async
}

protocol MainAppServiceClient: Sendable {
    func actualState() async -> LaunchAtLoginActualState
    func register() async throws
    func unregister() async throws
    func openSystemSettings() async
}

actor SystemMainAppServiceClient: MainAppServiceClient {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    func actualState() async -> LaunchAtLoginActualState {
        Self.map(service.status)
    }

    func register() async throws {
        try service.register()
    }

    func unregister() async throws {
        try await service.unregister()
    }

    func openSystemSettings() async {
        SMAppService.openSystemSettingsLoginItems()
    }

    nonisolated static func map(_ status: SMAppService.Status) -> LaunchAtLoginActualState {
        switch status {
        case .notRegistered:
            .disabled
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }
}

actor MainAppLaunchAtLoginService: LaunchAtLoginService {
    private let client: any MainAppServiceClient
    private var lastObservedState: LaunchAtLoginActualState?

    init(client: any MainAppServiceClient = SystemMainAppServiceClient()) {
        self.client = client
    }

    func refresh() async -> LaunchAtLoginSnapshot {
        let actualState = await client.actualState()
        let problem: LaunchAtLoginProblem?
        if let lastObservedState, lastObservedState != actualState {
            problem = .changedExternally
        } else {
            problem = nil
        }
        self.lastObservedState = actualState
        return LaunchAtLoginSnapshot(actualState: actualState, problem: problem)
    }

    func setEnabled(_ isEnabled: Bool) async -> LaunchAtLoginSnapshot {
        let initialState = await client.actualState()

        guard operationIsNeeded(for: initialState, isEnabled: isEnabled) else {
            lastObservedState = initialState
            return LaunchAtLoginSnapshot(
                actualState: initialState,
                problem: problemForUnavailableState(initialState, isEnabled: isEnabled)
            )
        }

        do {
            if isEnabled {
                try await client.register()
            } else {
                try await client.unregister()
            }
        } catch {
            return await mutationResult(
                isEnabled: isEnabled,
                forcedProblem: operationFailure(isEnabled: isEnabled)
            )
        }

        return await mutationResult(isEnabled: isEnabled, forcedProblem: nil)
    }

    func openSystemSettings() async {
        await client.openSystemSettings()
    }

    private func operationIsNeeded(
        for actualState: LaunchAtLoginActualState,
        isEnabled: Bool
    ) -> Bool {
        switch (isEnabled, actualState) {
        case (true, .disabled), (false, .enabled), (false, .requiresApproval):
            true
        case (true, .enabled), (true, .requiresApproval), (false, .disabled),
            (_, .unavailable):
            false
        }
    }

    private func problemForUnavailableState(
        _ actualState: LaunchAtLoginActualState,
        isEnabled: Bool
    ) -> LaunchAtLoginProblem? {
        guard actualState == .unavailable else {
            return nil
        }
        return operationFailure(isEnabled: isEnabled)
    }

    private func mutationResult(
        isEnabled: Bool,
        forcedProblem: LaunchAtLoginProblem?
    ) async -> LaunchAtLoginSnapshot {
        let actualState = await client.actualState()
        lastObservedState = actualState
        let problem =
            forcedProblem
            ?? (stateMatchesRequest(actualState, isEnabled: isEnabled)
                ? nil : operationFailure(isEnabled: isEnabled))
        return LaunchAtLoginSnapshot(actualState: actualState, problem: problem)
    }

    private func stateMatchesRequest(
        _ actualState: LaunchAtLoginActualState,
        isEnabled: Bool
    ) -> Bool {
        switch (isEnabled, actualState) {
        case (true, .enabled), (true, .requiresApproval), (false, .disabled):
            true
        case (true, .disabled), (false, .enabled), (false, .requiresApproval),
            (_, .unavailable):
            false
        }
    }

    private func operationFailure(isEnabled: Bool) -> LaunchAtLoginProblem {
        isEnabled ? .enableFailed : .disableFailed
    }
}
