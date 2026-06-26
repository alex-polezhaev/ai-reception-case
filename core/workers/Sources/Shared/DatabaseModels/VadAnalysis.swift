import Foundation

// MARK: - VadAnalysis struct

public struct VadAnalysis: Codable, Sendable {
    public let id: Int?
    public let vad_session_id: Int
    public let title: String
    public let type: String
    public let keywords: [String]
    public let products: [String]?
    public let quality: Int?
    public let optimized_text: String?

    public init(
        id: Int?,
        vad_session_id: Int,
        title: String,
        type: String,
        keywords: [String],
        products: [String]?,
        quality: Int?,
        optimized_text: String?
    ) {
        self.id = id
        self.vad_session_id = vad_session_id
        self.title = title
        self.type = type
        self.keywords = keywords
        self.products = products
        self.quality = quality
        self.optimized_text = optimized_text
    }
}
