import Foundation

// MARK: - TimelineSecond

public struct TimelineSecond: Codable, Sendable {
    public let pcm: Data?
    public let is_speech: Bool
    public let timestamp: Int

    public init(pcm: Data?, is_speech: Bool, timestamp: Int) {
        self.pcm = pcm
        self.is_speech = is_speech
        self.timestamp = timestamp
    }
}


public typealias Timeline = [TimelineSecond]


