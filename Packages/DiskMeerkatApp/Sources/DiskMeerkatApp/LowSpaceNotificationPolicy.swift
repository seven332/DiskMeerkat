enum DiskSpaceReadFailure: Equatable, Sendable {
    case invalidCapacity
    case unavailable
}

enum DiskSpaceReading: Equatable, Sendable {
    case available(DiskCapacity)
    case failed(DiskSpaceReadFailure)
}

enum NotificationEpisodeState: Equatable, Sendable {
    case armed
    case suppressed
}

enum NotificationSubmissionOutcome: Equatable, Sendable {
    case accepted
    case failed
}

struct LowSpaceNotificationCandidate: Equatable, Sendable {
    let availableCapacity: DiskCapacity
    let threshold: LowSpaceThreshold

    fileprivate init(availableCapacity: DiskCapacity, threshold: LowSpaceThreshold) {
        self.availableCapacity = availableCapacity
        self.threshold = threshold
    }

    func episodeState(after outcome: NotificationSubmissionOutcome) -> NotificationEpisodeState {
        switch outcome {
        case .accepted:
            .suppressed
        case .failed:
            .armed
        }
    }
}

enum NotificationDirective: Equatable, Sendable {
    case none
    case submit(LowSpaceNotificationCandidate)
}

enum DiskSpaceAssessment: Equatable, Sendable {
    case available(capacity: DiskCapacity, relationship: ThresholdRelationship)
    case unavailable(DiskSpaceReadFailure)
}

struct MonitoringEvaluation: Equatable, Sendable {
    let assessment: DiskSpaceAssessment
    let notificationDirective: NotificationDirective
    let nextEpisodeState: NotificationEpisodeState
}

enum LowSpaceNotificationPolicy {
    static func evaluate(
        reading: DiskSpaceReading,
        threshold: LowSpaceThreshold,
        episodeState: NotificationEpisodeState
    ) -> MonitoringEvaluation {
        switch reading {
        case .failed(let failure):
            return MonitoringEvaluation(
                assessment: .unavailable(failure),
                notificationDirective: .none,
                nextEpisodeState: episodeState
            )

        case .available(let capacity):
            let relationship = capacity.relationship(to: threshold)

            switch (episodeState, relationship) {
            case (.armed, .below):
                let candidate = LowSpaceNotificationCandidate(
                    availableCapacity: capacity,
                    threshold: threshold
                )
                return MonitoringEvaluation(
                    assessment: .available(capacity: capacity, relationship: relationship),
                    notificationDirective: .submit(candidate),
                    nextEpisodeState: .armed
                )

            case (.suppressed, .above):
                return MonitoringEvaluation(
                    assessment: .available(capacity: capacity, relationship: relationship),
                    notificationDirective: .none,
                    nextEpisodeState: .armed
                )

            case (.armed, .equal), (.armed, .above), (.suppressed, .below), (.suppressed, .equal):
                return MonitoringEvaluation(
                    assessment: .available(capacity: capacity, relationship: relationship),
                    notificationDirective: .none,
                    nextEpisodeState: episodeState
                )
            }
        }
    }
}
