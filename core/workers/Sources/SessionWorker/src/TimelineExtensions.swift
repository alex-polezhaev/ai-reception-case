// Timeline extensions: merging incomplete and new timelines.
import Foundation
import Shared

// MARK: - Timeline Extensions

extension Timeline {
    static func merge(incomplete: Timeline, new: Timeline) async throws -> Timeline {
        // Validate input data
        guard new.count == 60 else {
            throw NSError(domain: "Timeline", code: 1, userInfo: [
                "message": "New timeline must be 60 seconds",
                "actual_count": new.count,
            ])
        }

        guard !incomplete.isEmpty else { return new }

        // Check continuity of new timeline
        if new.count > 1 {
            guard let firstNew = new.first, let lastNew = new.last else {
                throw NSError(domain: "Timeline", code: 7, userInfo: [
                    "message": "New timeline data corruption",
                ])
            }
            guard lastNew.timestamp - firstNew.timestamp + 1 == new.count else {
                throw NSError(domain: "Timeline", code: 2, userInfo: [
                    "message": "New timeline has gaps",
                    "expected_duration": lastNew.timestamp - firstNew.timestamp + 1,
                    "actual_count": new.count,
                ])
            }
        }

        // Merge all seconds and sort by timestamp
        var allSeconds = incomplete + new
        allSeconds.sort { $0.timestamp < $1.timestamp }

        guard let firstTimestamp = allSeconds.first?.timestamp,
              let lastTimestamp = allSeconds.last?.timestamp else {
            throw NSError(domain: "Timeline", code: 6, userInfo: [
                "message": "Invalid timeline data",
            ])
        }

        // Build a map of existing seconds
        var secondsMap: [Int: TimelineSecond] = [:]
        for second in allSeconds {
            if let existing = secondsMap[second.timestamp] {
                // On duplicates, prefer seconds with PCM data
                if second.pcm != nil && existing.pcm == nil {
                    secondsMap[second.timestamp] = second
                }
            } else {
                secondsMap[second.timestamp] = second
            }
        }

        // Build a continuous timeline
        var result: Timeline = []

        for timestamp in firstTimestamp ... lastTimestamp {
            if let existing = secondsMap[timestamp] {
                result.append(existing)
            } else {
                // Fill the gap with silence
                result.append(TimelineSecond(
                    pcm: nil,
                    is_speech: false,
                    timestamp: timestamp
                ))
            }
        }

        // Self-validation
        guard result.count == lastTimestamp - firstTimestamp + 1 else {
            throw NSError(domain: "Timeline", code: 3, userInfo: [
                "message": "Merge validation failed: timeline length mismatch",
                "expected_length": lastTimestamp - firstTimestamp + 1,
                "actual_length": result.count,
            ])
        }

        guard let firstResult = result.first, let lastResult = result.last,
              firstResult.timestamp == firstTimestamp,
              lastResult.timestamp == lastTimestamp else {
            throw NSError(domain: "Timeline", code: 4, userInfo: [
                "message": "Merge validation failed: timestamp mismatch",
            ])
        }

        // Check continuity of the result
        for i in 1 ..< result.count {
            guard result[i].timestamp == result[i - 1].timestamp + 1 else {
                throw NSError(domain: "Timeline", code: 5, userInfo: [
                    "message": "Result timeline has gaps",
                    "gap_at_index": i,
                ])
            }
        }

        return result
    }
}
