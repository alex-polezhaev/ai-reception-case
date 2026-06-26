import Foundation

public enum AppLogLevel: String, Codable, Sendable {
    case info
    case error
}

public struct AppLog: Codable, Sendable {
    public let level: AppLogLevel
    public let timestamp: Date
    public let source: String
    public let message: String

    public init(level: AppLogLevel, timestamp: Date, source: String, message: String) {
        self.level = level
        self.timestamp = timestamp
        self.source = source
        self.message = message
    }
}
