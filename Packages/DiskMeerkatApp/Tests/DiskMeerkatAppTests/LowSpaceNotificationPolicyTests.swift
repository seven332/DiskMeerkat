import XCTest
@testable import DiskMeerkatApp

final class LowSpaceNotificationPolicyTests: XCTestCase {
    func testArmedStateSubmitsOnlyBelowThreshold() throws {
        let threshold = try LowSpaceThreshold(gigabytes: 100)
        let below = try DiskCapacity(bytes: threshold.bytes - 1)
        let equal = try DiskCapacity(bytes: threshold.bytes)
        let above = try DiskCapacity(bytes: threshold.bytes + 1)
        let belowSnapshot = StartupVolumeSnapshot(
            availableCapacity: below,
            volumeName: "Macintosh HD"
        )

        let belowEvaluation = LowSpaceNotificationPolicy.evaluate(
            reading: .available(belowSnapshot),
            threshold: threshold,
            episodeState: .armed
        )

        XCTAssertEqual(
            belowEvaluation.assessment,
            .available(startupVolume: belowSnapshot, relationship: .below)
        )
        XCTAssertEqual(belowEvaluation.nextEpisodeState, .armed)
        guard case .submit(let candidate) = belowEvaluation.notificationDirective else {
            return XCTFail("Expected a low-space notification candidate")
        }
        XCTAssertEqual(candidate.availableCapacity, below)
        XCTAssertEqual(candidate.volumeName, "Macintosh HD")
        XCTAssertEqual(candidate.startupVolume, belowSnapshot)
        XCTAssertEqual(candidate.threshold, threshold)

        for (capacity, relationship) in [(equal, ThresholdRelationship.equal), (above, .above)] {
            let snapshot = StartupVolumeSnapshot(availableCapacity: capacity, volumeName: nil)
            XCTAssertEqual(
                LowSpaceNotificationPolicy.evaluate(
                    reading: .available(snapshot),
                    threshold: threshold,
                    episodeState: .armed
                ),
                MonitoringEvaluation(
                    assessment: .available(startupVolume: snapshot, relationship: relationship),
                    notificationDirective: .none,
                    nextEpisodeState: .armed
                )
            )
        }
    }

    func testFailedReadingsPreserveEveryEpisodeState() throws {
        let threshold = try LowSpaceThreshold(gigabytes: 100)

        for episodeState in [NotificationEpisodeState.armed, .suppressed] {
            for failure in [DiskSpaceReadFailure.unavailable, .invalidCapacity] {
                XCTAssertEqual(
                    LowSpaceNotificationPolicy.evaluate(
                        reading: .failed(failure),
                        threshold: threshold,
                        episodeState: episodeState
                    ),
                    MonitoringEvaluation(
                        assessment: .unavailable(failure),
                        notificationDirective: .none,
                        nextEpisodeState: episodeState
                    )
                )
            }
        }
    }

    func testSubmissionOutcomeChangesStateOnlyAfterCandidateExists() throws {
        let threshold = try LowSpaceThreshold(gigabytes: 100)
        let capacity = try DiskCapacity(bytes: threshold.bytes - 1)
        let snapshot = StartupVolumeSnapshot(availableCapacity: capacity, volumeName: nil)
        let evaluation = LowSpaceNotificationPolicy.evaluate(
            reading: .available(snapshot),
            threshold: threshold,
            episodeState: .armed
        )

        guard case .submit(let candidate) = evaluation.notificationDirective else {
            return XCTFail("Expected a low-space notification candidate")
        }

        XCTAssertEqual(evaluation.nextEpisodeState, .armed)
        XCTAssertEqual(candidate.episodeState(after: .accepted), .suppressed)
        XCTAssertEqual(candidate.episodeState(after: .failed), .armed)
    }

    func testSuppressedStateRearmsOnlyAboveThreshold() throws {
        let threshold = try LowSpaceThreshold(gigabytes: 100)
        let values: [(Int64, ThresholdRelationship, NotificationEpisodeState)] = [
            (threshold.bytes - 1, .below, .suppressed),
            (threshold.bytes, .equal, .suppressed),
            (threshold.bytes + 1, .above, .armed),
        ]

        for (bytes, relationship, expectedState) in values {
            let capacity = try DiskCapacity(bytes: bytes)
            let snapshot = StartupVolumeSnapshot(availableCapacity: capacity, volumeName: nil)
            XCTAssertEqual(
                LowSpaceNotificationPolicy.evaluate(
                    reading: .available(snapshot),
                    threshold: threshold,
                    episodeState: .suppressed
                ),
                MonitoringEvaluation(
                    assessment: .available(startupVolume: snapshot, relationship: relationship),
                    notificationDirective: .none,
                    nextEpisodeState: expectedState
                )
            )
        }
    }

    func testThresholdChangesUseTheSameTransitionRules() throws {
        let capacity = try DiskCapacity(bytes: 90_000_000_000)
        let snapshot = StartupVolumeSnapshot(availableCapacity: capacity, volumeName: nil)
        let lowerThreshold = try LowSpaceThreshold(gigabytes: 80)
        let higherThreshold = try LowSpaceThreshold(gigabytes: 100)

        XCTAssertEqual(
            LowSpaceNotificationPolicy.evaluate(
                reading: .available(snapshot),
                threshold: lowerThreshold,
                episodeState: .suppressed
            ).nextEpisodeState,
            .armed
        )

        let raisedThresholdEvaluation = LowSpaceNotificationPolicy.evaluate(
            reading: .available(snapshot),
            threshold: higherThreshold,
            episodeState: .armed
        )
        XCTAssertEqual(raisedThresholdEvaluation.nextEpisodeState, .armed)
        guard case .submit = raisedThresholdEvaluation.notificationDirective else {
            return XCTFail("Raising the threshold should make an armed low reading eligible")
        }
    }
}
