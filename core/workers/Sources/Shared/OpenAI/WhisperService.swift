// WhisperService: transcribes audio via the OpenAI Whisper API.
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

extension OpenAIClient {

    public func transcribe(
        file: Data,
        fileName: String = "audio.wav",
        model: String = "whisper-1",
        language: String? = nil,
        prompt: String? = nil,
        temperature: Double? = nil
    ) async throws -> WhisperVerboseResponse {
        let boundary = UUID().uuidString
        var buffer = ByteBufferAllocator().buffer(capacity: 0)

        func writePart(name: String, value: String) {
            buffer.writeString("--\(boundary)\r\n")
            buffer.writeString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            buffer.writeString(value)
            buffer.writeString("\r\n")
        }

        // File part
        buffer.writeString("--\(boundary)\r\n")
        buffer.writeString("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        buffer.writeString("Content-Type: audio/wav\r\n\r\n")
        buffer.writeBytes(file)
        buffer.writeString("\r\n")

        // Required
        writePart(name: "model", value: model)
        writePart(name: "response_format", value: "verbose_json")

        // Optional
        if let prompt = prompt {
            writePart(name: "prompt", value: prompt)
        }

        if let language = language {
            writePart(name: "language", value: language)
        }

        if let temperature = temperature {
            writePart(name: "temperature", value: String(temperature))
        }

        buffer.writeString("--\(boundary)--\r\n")

        var request = HTTPClientRequest(url: "https://api.openai.com/v1/audio/transcriptions")
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: "multipart/form-data; boundary=\(boundary)")
        request.body = .bytes(buffer)

        let data = try await execute(request, errorPrefix: "Whisper error")
        return try JSONDecoder().decode(WhisperVerboseResponse.self, from: data)
    }
}
