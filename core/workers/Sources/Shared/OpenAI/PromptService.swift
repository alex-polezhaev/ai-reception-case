// PromptService: executes stored OpenAI prompts with typed variables and results.
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

public extension OpenAIClient {
    func executePrompt<Variables: Codable, Result: Codable>(
        promptId: String,
        variables: Variables,
        as type: Result.Type
    ) async throws -> Result {
        let requestBody = OpenAIRequest(
            prompt: PromptData(
                id: promptId,
                variables: variables
            )
        )

        let request = try makeJSONRequest(
            url: "https://api.openai.com/v1/responses",
            method: .POST,
            body: requestBody
        )

        let data = try await execute(request, errorPrefix: "Responses API error")

        let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard
            let outputBlock = apiResponse.output.first,
            let contentBlock = outputBlock.content.first,
            contentBlock.type == "output_text"
        else {
            throw OpenAIError.decodingError("No output_text found in response content")
        }

        guard let jsonData = contentBlock.text.data(using: .utf8) else {
            throw OpenAIError.decodingError("output_text is not valid UTF-8")
        }

        do {
            return try JSONDecoder().decode(Result.self, from: jsonData)
        } catch {
            throw OpenAIError.decodingError("Failed to decode result: \(error.localizedDescription)")
        }
    }
}
