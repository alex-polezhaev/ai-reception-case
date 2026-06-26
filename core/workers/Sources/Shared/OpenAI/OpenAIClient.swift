// OpenAIClient: low-level HTTP client for the OpenAI API (request building and execution).
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1
import Supabase

public final class OpenAIClient {
    let apiKey: String
    private let httpClient: HTTPClient

    public init(_ supabase: SupabaseClient) async throws {
        apiKey = try env("OPENAI_API_KEY", as: String.self)
        var config = HTTPClient.Configuration()

        #if !DEBUG
            let proxy: Proxy = try await supabase
                .from("proxies")
                .select()
                .order("priority", ascending: false)
                .limit(1)
                .single()
                .execute()
                .value

            config.proxy = .server(
                host: proxy.host,
                port: proxy.port,
                authorization: .basic(username: proxy.username, password: proxy.password)
            )
        #endif

        httpClient = HTTPClient(
            eventLoopGroupProvider: .shared(AppEventLoopGroup.shared),
            configuration: config
        )
    }

    deinit {
        try? httpClient.syncShutdown()
    }

    func makeJSONRequest<T: Encodable>(
        url: String,
        method: HTTPMethod,
        body: T
    ) throws -> HTTPClientRequest {
        var request = HTTPClientRequest(url: url)
        request.method = method
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = try .bytes(JSONEncoder().encode(body))
        return request
    }

    func execute(_ request: HTTPClientRequest, errorPrefix: String) async throws -> Data {
        let response: HTTPClientResponse
        do {
            response = try await httpClient.execute(request, timeout: .seconds(120))
        } catch {
            throw error
        }

        // Safely read body
        var buffer = try await response.body.collect(upTo: 5 * 1024 * 1024)
        let data = buffer.readData(length: buffer.readableBytes) ?? Data()

        guard response.status == .ok else {
            let errorText = String(data: data, encoding: .utf8) ?? "<non-UTF8 response>"
            throw OpenAIError.apiError(Int(response.status.code), errorText)
        }

        return data
    }
}
