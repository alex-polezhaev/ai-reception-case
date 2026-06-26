import Foundation

public struct SilenceChunk: Codable, Sendable {
    public let id: Int?
    public let timestamp: Date
    public let device_id: String

    public init(id: Int?, timestamp: Date, device_id: String) {
        self.id = id
        self.timestamp = timestamp
        self.device_id = device_id
    }
}
