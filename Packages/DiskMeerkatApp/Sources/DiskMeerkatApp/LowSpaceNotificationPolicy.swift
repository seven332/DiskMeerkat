enum DiskSpaceReadFailure: Equatable, Sendable {
    case invalidCapacity
    case unavailable
}

struct StartupVolumeSnapshot: Equatable, Sendable {
    let availableCapacity: DiskCapacity
    let volumeName: String?
}

enum DiskSpaceReading: Equatable, Sendable {
    case available(StartupVolumeSnapshot)
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
    let startupVolume: StartupVolumeSnapshot
    let threshold: LowSpaceThreshold

    var availableCapacity: DiskCapacity {
        startupVolume.availableCapacity
    }

    var volumeName: String? {
        startupVolume.volumeName
    }

    fileprivate init(startupVolume: StartupVolumeSnapshot, threshold: LowSpaceThreshold) {
        self.startupVolume = startupVolume
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
    case available(startupVolume: StartupVolumeSnapshot, relationship: ThresholdRelationship)
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

        case .available(let startupVolume):
            let relationship = startupVolume.availableCapacity.relationship(to: threshold)

            switch (episodeState, relationship) {
            case (.armed, .below):
                let candidate = LowSpaceNotificationCandidate(
                    startupVolume: startupVolume,
                    threshold: threshold
                )
                return MonitoringEvaluation(
                    assessment: .available(
                        startupVolume: startupVolume,
                        relationship: relationship
                    ),
                    notificationDirective: .submit(candidate),
                    nextEpisodeState: .armed
                )

            case (.suppressed, .above):
                return MonitoringEvaluation(
                    assessment: .available(
                        startupVolume: startupVolume,
                        relationship: relationship
                    ),
                    notificationDirective: .none,
                    nextEpisodeState: .armed
                )

            case (.armed, .equal), (.armed, .above), (.suppressed, .below), (.suppressed, .equal):
                return MonitoringEvaluation(
                    assessment: .available(
                        startupVolume: startupVolume,
                        relationship: relationship
                    ),
                    notificationDirective: .none,
                    nextEpisodeState: episodeState
                )
            }
        }
    }
}
