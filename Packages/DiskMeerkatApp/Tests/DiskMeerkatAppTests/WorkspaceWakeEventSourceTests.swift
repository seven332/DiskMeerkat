import AppKit
import Foundation
import XCTest

@testable import DiskMeerkatApp

@MainActor
final class WorkspaceWakeEventSourceTests: XCTestCase {
    func testSystemObserverUsesInjectedWorkspaceCenterAndRemovesTokenIdempotently() {
        let center = NotificationCenter()
        let workspace = NSWorkspace.shared
        let observer = SystemWorkspaceWakeObserver(workspace: workspace, center: center)
        var receivedCount = 0
        let token = observer.addWakeObserver {
            receivedCount += 1
        }

        center.post(name: NSWorkspace.didWakeNotification, object: workspace)
        XCTAssertEqual(receivedCount, 1)

        observer.removeWakeObserver(token)
        observer.removeWakeObserver(token)
        center.post(name: NSWorkspace.didWakeNotification, object: workspace)
        XCTAssertEqual(receivedCount, 1)
    }

    func testOneStreamInstallsOneObserverAndForwardsWakeEvents() async {
        let observer = RecordingWorkspaceWakeObserver()
        let source = WorkspaceWakeEventSource(observer: observer)
        let stream = await source.events()
        let receivedEvents = AsyncEventCounter()
        let consumer = Task {
            for await _ in stream {
                await receivedEvents.record()
            }
        }

        XCTAssertEqual(observer.addedTokens.count, 1)
        XCTAssertEqual(observer.activeTokenCount, 1)

        observer.sendWake()
        await receivedEvents.waitForCount(1)
        let receivedCount = await receivedEvents.value()
        XCTAssertEqual(receivedCount, 1)

        consumer.cancel()
        await consumer.value
        await waitForRemovalCount(1, observer: observer)
        XCTAssertEqual(observer.activeTokenCount, 0)
        XCTAssertEqual(observer.removedTokens.count, 1)
    }

    func testSourceDeinitializationFinishesStreamAndRemovesObserver() async {
        let observer = RecordingWorkspaceWakeObserver()
        var source: WorkspaceWakeEventSource? = WorkspaceWakeEventSource(observer: observer)
        guard let stream = await source?.events() else {
            return XCTFail("Expected a wake-event stream")
        }
        let consumer = Task {
            for await _ in stream {}
        }
        weak let weakSource = source

        source = nil

        XCTAssertNil(weakSource)
        await consumer.value
        XCTAssertEqual(observer.activeTokenCount, 0)
        XCTAssertEqual(observer.removedTokens.count, 1)
    }

    func testNewSubscriptionReplacesTheOldObserverWithoutOverlap() async {
        let observer = RecordingWorkspaceWakeObserver()
        let source = WorkspaceWakeEventSource(observer: observer)
        let firstStream = await source.events()
        let receivedEvents = AsyncEventCounter()
        let firstConsumer = Task {
            for await _ in firstStream {
                await receivedEvents.record()
            }
        }

        XCTAssertEqual(observer.addedTokens.count, 1)
        XCTAssertEqual(observer.activeTokenCount, 1)

        let secondStream = await source.events()
        let secondConsumer = Task {
            for await _ in secondStream {
                await receivedEvents.record()
            }
        }

        XCTAssertEqual(observer.addedTokens.count, 2)
        XCTAssertEqual(Set(observer.addedTokens).count, 2)
        XCTAssertEqual(observer.activeTokenCount, 1)
        XCTAssertEqual(observer.removedTokens, [observer.addedTokens[0]])
        await firstConsumer.value

        observer.sendWake()
        await receivedEvents.waitForCount(1)
        let receivedCount = await receivedEvents.value()
        XCTAssertEqual(receivedCount, 1)

        secondConsumer.cancel()
        await secondConsumer.value
        await waitForRemovalCount(2, observer: observer)
        XCTAssertEqual(observer.activeTokenCount, 0)
        XCTAssertEqual(Set(observer.removedTokens), Set(observer.addedTokens))
    }

    private func waitForRemovalCount(
        _ expectedCount: Int,
        observer: RecordingWorkspaceWakeObserver,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<100 where observer.removedTokens.count < expectedCount {
            await Task.yield()
        }
        XCTAssertEqual(observer.removedTokens.count, expectedCount, file: file, line: line)
    }
}

@MainActor
private final class RecordingWorkspaceWakeObserver: WorkspaceWakeObserver {
    private var handlers: [WorkspaceWakeObservationToken: @MainActor @Sendable () -> Void] = [:]
    private(set) var addedTokens: [WorkspaceWakeObservationToken] = []
    private(set) var removedTokens: [WorkspaceWakeObservationToken] = []

    var activeTokenCount: Int {
        handlers.count
    }

    func addWakeObserver(
        _ handler: @escaping @MainActor @Sendable () -> Void
    ) -> WorkspaceWakeObservationToken {
        let token = WorkspaceWakeObservationToken()
        handlers[token] = handler
        addedTokens.append(token)
        return token
    }

    func removeWakeObserver(_ token: WorkspaceWakeObservationToken) {
        guard handlers.removeValue(forKey: token) != nil else {
            return
        }
        removedTokens.append(token)
    }

    func sendWake() {
        for handler in handlers.values {
            handler()
        }
    }
}

private actor AsyncEventCounter {
    private var count = 0
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func record() {
        count += 1
        var remaining: [(Int, CheckedContinuation<Void, Never>)] = []
        for (expectedCount, continuation) in waiters {
            if count >= expectedCount {
                continuation.resume()
            } else {
                remaining.append((expectedCount, continuation))
            }
        }
        waiters = remaining
    }

    func waitForCount(_ expectedCount: Int) async {
        guard count < expectedCount else {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append((expectedCount, continuation))
        }
    }

    func value() -> Int {
        count
    }
}
