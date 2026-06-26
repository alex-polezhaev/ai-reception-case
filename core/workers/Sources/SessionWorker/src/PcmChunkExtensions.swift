// PcmChunk extensions: convert stored PCM chunks into per-second timelines.
import Foundation
import Shared

extension PcmChunk {
    func toTimeline() async throws -> Timeline {
        let startTimestamp = Int(self.timestamp.timeIntervalSince1970)
        let endTimestamp = Int(self.end_timestamp.timeIntervalSince1970)

        // Download PCM data from S3
        let s3 = try S3Wrapper()
        let bucket = try env("S3_DEVICE_PCM_BUCKET", as: String.self)
        let pcmData = try await s3.download(bucket: bucket, key: self.s3_key)

        // Validate PCM data
        let expectedBytes = self.duration * AudioConfig.bytesPerSecond
        guard pcmData.count >= expectedBytes else {
            throw NSError(domain: "PcmChunk", code: 4, userInfo: [
                "message": "Insufficient PCM data",
                "expected_bytes": expectedBytes,
                "actual_bytes": pcmData.count,
                "chunk_id": self.id ?? "unknown"
            ])
        }

        guard let vadTimeline = self.vad_timeline,
              vadTimeline.count == self.duration else {
            throw NSError(domain: "PcmChunk", code: 5, userInfo: [
                "message": "VAD timeline length mismatch",
                "expected_length": self.duration,
                "actual_length": self.vad_timeline?.count ?? 0,
                "chunk_id": self.id ?? "unknown"
            ])
        }

        // Build timeline
        var timeline: Timeline = []

        for (index, second) in (startTimestamp..<endTimestamp).enumerated() {
        let isSpeech = vadTimeline[index] == 1

        // Extract PCM data for this second
        let bytesPerSecond = AudioConfig.bytesPerSecond
        let startByte = index * bytesPerSecond
        let endByte = min(startByte + bytesPerSecond, pcmData.count)

        let pcmSecondData: Data? = startByte < pcmData.count ?
        pcmData.subdata(in: startByte..<endByte) : nil

            timeline.append(TimelineSecond(
                pcm: pcmSecondData,
                is_speech: isSpeech,
                timestamp: second
            ))
        }

        // Self-validation
        guard timeline.count == self.duration else {
            throw NSError(domain: "PcmChunk", code: 1, userInfo: [
                "message": "Timeline validation failed",
                "expected_duration": self.duration,
                "actual_duration": timeline.count,
                "chunk_id": self.id ?? "unknown"
            ])
        }

        return timeline
    }
}
