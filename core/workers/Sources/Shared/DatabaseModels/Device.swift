import Foundation

public struct Device: Codable, Sendable {
    public let id: String
    public let title: String?
    public let boot_at: Date?
    public let last_active_at: Date?
    public let activated_at: Date?
    public let bad_vad_count: Int
    public let incomplete_timestamp: Date?
}
