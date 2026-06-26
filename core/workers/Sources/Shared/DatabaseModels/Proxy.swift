import Foundation

public struct Proxy: Codable, Sendable {
    public let host: String
    public let port: Int
    public let username: String
    public let password: String
    public let priority: Int
}
