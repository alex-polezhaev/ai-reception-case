// Timeline active-region detection: groups timeline seconds into active speech regions.
import Foundation
import Shared

typealias ActiveRegion = [TimelineSecond]

extension Timeline {
    func activeRegions(activityWindow: Int, activityThreshold: Double) -> [ActiveRegion] {
        guard count >= activityWindow else { return [] }

        var regions: [ClosedRange<Int>] = []
        var start: Int?

        for i in 0 ... (count - activityWindow) {
            let activity = Double(self[i ..< (i + activityWindow)].count { $0.is_speech }) / Double(activityWindow)

            if activity >= activityThreshold {
                start = start ?? i
            } else if let s = start {
                regions.append(s ... (i - 1))  // Fix: do not capture the extra window
                start = nil
            }
        }

        if let s = start {
            regions.append(s ... (count - 1))
        }

        return regions.map { Array(self[$0]) }
    }
}

typealias SessionTimeline = [TimelineSecond]

extension Array where Element == ActiveRegion {
    func sessions(endSilenceDuration: Int, minSessionLength: Int) throws -> (completed: [SessionTimeline], incomplete: SessionTimeline) {
        guard !isEmpty else { return ([], []) }

        var sessions: [SessionTimeline] = []
        var currentSession = self[0] // Start with the first region

        // Iterate over remaining regions (from index 1)
        for nextRegion in self.dropFirst() {
            let gap = nextRegion.first!.timestamp - currentSession.last!.timestamp - 1

            if gap <= endSilenceDuration {
                // Regions are close — merge into one session
                if gap > 0 {
                    // Fill the gap with silence
                    for i in 1...gap {
                        currentSession.append(TimelineSecond(pcm: nil, is_speech: false,
                                            timestamp: currentSession.last!.timestamp + i))
                    }
                }
                currentSession += nextRegion
            } else {
                // Large gap — end the current session
                sessions.append(currentSession)
                currentSession = nextRegion // Start a new session
            }
        }
        sessions.append(currentSession) // Append the last session

        // Determine completeness of the last session based on its last timestamp
        guard let lastSession = sessions.last,
              let lastSessionTimestamp = lastSession.last?.timestamp else {
            return ([], [])
        }

        let now = Int(Date().timeIntervalSince1970)
        let timeSinceLastActivity = now - lastSessionTimestamp
        let isComplete = timeSinceLastActivity >= endSilenceDuration * 3 // If more than 3 silence intervals have passed, force-complete the session. Guards against a stuck silence state

        if isComplete {
            let filtered = sessions.filter { $0.duration >= minSessionLength }
            return (filtered, [])
        } else {
            let completed = Array(sessions.dropLast()).filter { $0.duration >= minSessionLength }
            return (completed, sessions.last!)
        }
    }
}
