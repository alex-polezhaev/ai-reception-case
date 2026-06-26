import Foundation

struct SessionRead: Codable {
    let id: Int?
    let telegram_account_id: Int
    let vad_session_id: Int
    let read_at: Date

    enum CodingKeys: String, CodingKey {
        case id
        case telegram_account_id
        case vad_session_id
        case read_at
    }
}

extension SessionRead {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(Int.self, forKey: .id)
        telegram_account_id = try container.decode(Int.self, forKey: .telegram_account_id)
        vad_session_id = try container.decode(Int.self, forKey: .vad_session_id)

        if let dateString = try? container.decode(String.self, forKey: .read_at) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            read_at = formatter.date(from: dateString) ?? Date()
        } else {
            read_at = try container.decode(Date.self, forKey: .read_at)
        }
    }
}
