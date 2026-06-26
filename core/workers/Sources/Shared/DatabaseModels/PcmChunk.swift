import Foundation

public struct PcmChunk: Codable, Sendable {
    public let id: Int?
    public let device_id: String
    public let s3_key: String
    public let vad_timeline: [Int]?
    public let timestamp: Date
    public let duration: Int
    public var end_timestamp: Date {
        // Inclusive start, exclusive end
        timestamp.addingTimeInterval(TimeInterval(duration))
    }


    public init(id: Int?, s3_key: String, timestamp: Date, duration: Int, device_id: String, vad_timeline: [Int]?) {
        self.id = id
        self.s3_key = s3_key
        self.timestamp = timestamp
        self.duration = duration
        self.device_id = device_id
        self.vad_timeline = vad_timeline
    }
}
