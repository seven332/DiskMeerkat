import XCTest
@testable import DiskMeerkatApp

final class LowSpaceNotificationPolicyTests: XCTestCase {
    func testArmedStateSubmitsOnlyBelowThreshold() throws {
        let threshold = try LowSpaceThreshold(gigabytes: 100)
        let below = try DiskCapacity(bytes: threshold.bytes - 1)
        let equal = try DiskCapacity(bytes: threshold.bytes)
        let above = try DiskCapacity(bytes: threshold.bytes + 1)

        let belowEvaluation = LowSpaceNotificationPolicy.evaluate(
            reading: .available(below),
            threshold: threshold,
            episodeState: .armed
        )

        XCTAssertEqual(
            belowEvaluation,
            MonitoringEvaluation(
                assessment: .available(capacity: below, relationship: .below),
                notificationDirective: .submit(
                    LowSpaceNotificationCandidate(availableCapacity: below, threshold: threshold)
                ),
                nextEpisodeState: .armed
            )
        )

        for (capacity, relationship) in [(equal, ThresholdRelationship.equal), (above, .above)] {
            XCTAssertEqual(
                LowSpaceNotificationPolicy.evaluate(
                    reading: .available(capacity),
                    threshold: threshold,
                    episodeState: .armed
                ),
                MonitoringEvaluation(
                    assessment: .available(capacity: capacity, relationship: relationship),
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
        let evaluation = LowSpaceNotificationPolicy.evaluate(
            reading: .available(capacity),
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
            XCTAssertEqual(
                LowSpaceNotificationPolicy.evaluate(
                    reading: .available(capacity),
                    threshold: threshold,
                    episodeState: .suppressed
                ),
                MonitoringEvaluation(
                    assessment: .available(capacity: capacity, relationship: relationship),
                    notificationDirective: .none,
                    nextEpisodeState: expectedState
                )
            )
        }
    }

    func testThresholdChangesUseTheSameTransitionRules() throws {
        let capacity = try DiskCapacity(bytes: 90_000_000_000)
        let lowerThreshold = try LowSpaceThreshold(gigabytes: 80)
        let higherThreshold = try LowSpaceThreshold(gigabytes: 100)

        XCTAssertEqual(
            LowSpaceNotificationPolicy.evaluate(
                reading: .available(capacity),
                threshold: lowerThreshold,
                episodeState: .suppressed
            ).nextEpisodeState,
            .armed
        )

        let raisedThresholdEvaluation = LowSpaceNotificationPolicy.evaluate(
            reading: .available(capacity),
            threshold: higherThreshold,
            episodeState: .armed
        )
        XCTAssertEqual(raisedThresholdEvaluation.nextEpisodeState, .armed)
        guard case .submit = raisedThresholdEvaluation.notificationDirective else {
            return XCTFail("Raising the threshold should make an armed low reading eligible")
        }
    }
}
