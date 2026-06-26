import Foundation

// Telegram user model (no Vapor dependencies)
public struct TelegramUser: Codable, Sendable {
    public let id: Int64
    public let firstName: String
    public let lastName: String?
    public let username: String?
    public let languageCode: String?
    public let photoUrl: String?
    public let isPremium: Bool?

    public init(id: Int64, firstName: String, lastName: String? = nil, username: String? = nil, languageCode: String? = nil, photoUrl: String? = nil, isPremium: Bool? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.languageCode = languageCode
        self.photoUrl = photoUrl
        self.isPremium = isPremium
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case languageCode = "language_code"
        case photoUrl = "photo_url"
        case isPremium = "is_premium"
    }
}
