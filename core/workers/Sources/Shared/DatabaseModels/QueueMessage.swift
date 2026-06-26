import Foundation

public struct QueueMessage<T: Codable & Sendable>: Codable, Sendable {
    public let msg_id: Int
    public let message: T
    let enqueued_at: String
    let vt: String?
    let read_ct: Int?
}

public struct AnalysisMessage: Codable, Sendable {
    public let vad_session_id: Int
}

public struct TranscriptionMessage: Codable, Sendable {
    public let vad_session_id: Int
}

public struct SessionMessage: Codable, Sendable {
    public let pcm_chunk_id: Int
}
