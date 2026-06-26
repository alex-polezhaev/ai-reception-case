// Session timeline beautification helpers (duration and timeline trimming).
import Foundation
import Shared

extension Timeline {
    var duration: Int {
        guard let first = first, let last = last else { return 0 }
        return last.timestamp - first.timestamp + 1
    }

    func trimEdges() -> Timeline {
        guard let firstSpeech = firstIndex(where: \.is_speech),
              let lastSpeech = lastIndex(where: \.is_speech) else { return [] }

        return Array(self[firstSpeech ... lastSpeech])
    }

    func trimInnerSilence(maxInnerSilence: Int, minSilenceToTrim: Int) -> Timeline {
        guard count > minSilenceToTrim else { return self }

        var result: Timeline = []
        var i = 0

        while i < count {
            if self[i].is_speech {
                result.append(self[i])
                i += 1
            } else {
                // Find the length of the silence segment
                let silenceStart = i
                while i < count && !self[i].is_speech { i += 1 }
                let silenceLength = i - silenceStart

                if silenceLength >= minSilenceToTrim {
                    // Replace long silence with short silence
                    for j in 0..<Swift.min(maxInnerSilence, silenceLength) {
                        result.append(self[silenceStart + j])
                    }
                } else {
                    // Keep short silence as-is
                    for j in silenceStart..<i {
                        result.append(self[j])
                    }
                }
            }
        }

        return result
    }
}
