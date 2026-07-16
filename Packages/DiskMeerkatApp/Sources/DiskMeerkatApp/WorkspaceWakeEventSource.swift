import AppKit
import Foundation

struct WorkspaceWakeObservationToken: Hashable, Sendable {
    private let id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }
}

@MainActor
protocol WorkspaceWakeObserver: Sendable {
    func addWakeObserver(
        _ handler: @escaping @MainActor @Sendable () -> Void
    ) -> WorkspaceWakeObservationToken
    func removeWakeObserver(_ token: WorkspaceWakeObservationToken)
}

@MainActor
final class SystemWorkspaceWakeObserver: WorkspaceWakeObserver {
    private let center: NotificationCenter
    private let workspace: NSWorkspace
    private var observations: [WorkspaceWakeObservationToken: NotificationCenter.ObservationToken] =
        [:]

    init(
        workspace: NSWorkspace = .shared,
        center: NotificationCenter? = nil
    ) {
        self.workspace = workspace
        self.center = center ?? workspace.notificationCenter
    }

    func addWakeObserver(
        _ handler: @escaping @MainActor @Sendable () -> Void
    ) -> WorkspaceWakeObservationToken {
        let token = WorkspaceWakeObservationToken()
        let observation = center.addObserver(of: workspace, for: .didWake) {
            (_: NSWorkspace.DidWakeMessage) in
            handler()
        }
        observations[token] = observation
        return token
    }

    func removeWakeObserver(_ token: WorkspaceWakeObservationToken) {
        guard let observation = observations.removeValue(forKey: token) else {
            return
        }
        center.removeObserver(observation)
    }
}

@MainActor
final class WorkspaceWakeEventSource: MonitoringWakeEventSource {
    private struct Subscription {
        let id: UUID
        let token: WorkspaceWakeObservationToken
        let continuation: AsyncStream<Void>.Continuation
    }

    private let observer: any WorkspaceWakeObserver
    private var activeSubscription: Subscription?

    init(observer: any WorkspaceWakeObserver = SystemWorkspaceWakeObserver()) {
        self.observer = observer
    }

    isolated deinit {
        guard let subscription = activeSubscription else {
            return
        }
        observer.removeWakeObserver(subscription.token)
        subscription.continuation.finish()
    }

    func events() async -> AsyncStream<Void> {
        endActiveSubscription()
        let subscriptionID = UUID()
        return AsyncStream { continuation in
            let token = observer.addWakeObserver {
                continuation.yield()
            }
            activeSubscription = Subscription(
                id: subscriptionID,
                token: token,
                continuation: continuation
            )
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.endSubscription(id: subscriptionID)
                }
            }
        }
    }

    private func endSubscription(id: UUID) {
        guard activeSubscription?.id == id else {
            return
        }
        endActiveSubscription()
    }

    private func endActiveSubscription() {
        guard let subscription = activeSubscription else {
            return
        }
        activeSubscription = nil
        observer.removeWakeObserver(subscription.token)
        subscription.continuation.finish()
    }
}
