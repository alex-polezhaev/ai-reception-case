import Foundation

public struct VadSession: Codable, Sendable {
    public let id: Int?
    public let device_id: String
    public let s3_key: String
    public let timestamp: Date
    public let duration: Int
    public let is_unsuitable: Bool? // Flag indicating the session is unsuitable for analysis
    public let is_read: Bool?

    public var end_timestamp: Date {
        // Inclusive start, exclusive end
        timestamp.addingTimeInterval(TimeInterval(duration))
    }

    // MARK: - Timeline-based initialization

    public init(timeline: Timeline, deviceId: String, supabaseWrapper: SupabaseWrapper) async throws {
        guard !timeline.isEmpty else {
            throw NSError(domain: "VadSession", code: 1, userInfo: ["message": "Empty timeline"])
        }

        let startTimestamp = timeline.first!.timestamp
        let endTimestamp = timeline.last!.timestamp + 1
        let duration = endTimestamp - startTimestamp
        let s3Key = "\(deviceId)/\(startTimestamp).wav"

        var pcmData = Data()

        for second in timeline {
            if let pcm = second.pcm {
                pcmData.append(pcm)
            } else {
                pcmData.append(Data(count: AudioConfig.bytesPerSecond))
            }
        }

        let wavData = pcmData.toWav()

        let s3 = try S3Wrapper()
        let bucketName = try env("S3_SESSIONS_WAV_BUCKET", as: String.self)

        try await s3.upload(bucket: bucketName, key: s3Key, data: wavData)

        self.id = nil
        self.device_id = deviceId
        self.s3_key = s3Key
        self.timestamp = Date(timeIntervalSince1970: TimeInterval(startTimestamp))
        self.duration = duration
        self.is_unsuitable = false
        self.is_read = false
    }
}
