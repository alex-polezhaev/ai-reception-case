// SileroVADService: client for the Python Silero VAD service; returns a per-second speech mask for audio.
import Foundation
import Shared
import Vapor

struct SileroVADService {
    private let sileroURL: String

    init() throws {
        sileroURL = try env("SILERO_VAD_URL", as: String.self)
    }

    func processAudio(audioData: Data, on req: Request) async throws -> [Int] {
        // Convert PCM Data to an Int16 array (16-bit data)
        let pcmArray = audioData.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Int16.self)).map { Int($0) }
        }

        let requestBody = SileroVADRequest(pcm_data: pcmArray)
        let jsonData = try JSONEncoder().encode(requestBody)

        let response = try await req.client.post(URI(string: "\(sileroURL)/vad")) { request in
            request.headers.add(name: .contentType, value: "application/json")
            request.body = .init(data: jsonData)
        }

        guard response.status == .ok else {
            return Array(repeating: 0, count: 60)
        }

        let vadResponse = try response.content.decode(SileroVADResponse.self)
        return vadResponse.speech_mask
    }
}

// MARK: - Models

private struct SileroVADRequest: Codable {
    let pcm_data: [Int] // Changed from [Int32] to [Int] for 16-bit data
}

private struct SileroVADResponse: Codable {
    let speech_mask: [Int]
}
