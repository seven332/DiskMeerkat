import Foundation
import XCTest

@testable import DiskMeerkatApp

final class SystemMonitoringTimeTests: XCTestCase {
    func testWallClockForwardsInjectedDate() async {
        let expectedDate = Date(timeIntervalSince1970: 1_234_567)
        let clock = SystemMonitoringWallClock { expectedDate }

        let date = await clock.now()

        XCTAssertEqual(date, expectedDate)
    }

    func testSuspendingSchedulerPreservesCancellation() async {
        let scheduler = SuspendingMonitoringScheduler()
        let sleepTask = Task {
            try await scheduler.sleep(for: .seconds(86_400))
        }
        await Task.yield()

        sleepTask.cancel()

        do {
            try await sleepTask.value
            XCTFail("Expected suspending sleep to be cancelled")
        } catch is CancellationError {
            // Cancellation is the expected runtime shutdown/replacement path.
        } catch {
            XCTFail("Expected CancellationError, received \(error)")
        }
    }
}
