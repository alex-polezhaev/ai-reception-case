import Foundation

/// Transcription with segments. May include `id` if needed for Supabase upsert/select.
public struct VadTranscription: Codable, Sendable {
    public let id: Int?
    public let vad_session_id: Int
    public let text: String
    public let segments: [TranscriptionSegment]

    public init(
        id: Int?,
        vad_session_id: Int,
        text: String,
        segments: [TranscriptionSegment]
    ) {
        self.id = id
        self.vad_session_id = vad_session_id
        self.text = text
        self.segments = segments
    }
}

/// A single segment from Whisper verbose_json.
public struct TranscriptionSegment: Codable, Sendable {
    public let start: Double
    public let end: Double
    public let text: String

    public init(start: Double, end: Double, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }
}
