// ErrorApiMiddleware: converts thrown errors into JSON API error responses and logs them.
import Shared
import Supabase
import Vapor

struct ErrorApiMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Check exclusions
        let shouldSkipLogging = ErrorLogger.shouldSkipLogging(method: request.method.rawValue, path: request.url.path)

        let start = Date()

        do {
            let response = try await next.respond(to: request)

            // Log only 5xx status codes (except excluded routes)
            if response.status.code >= 500 && !shouldSkipLogging {
                await logError(
                    request: request,
                    statusCode: Int(response.status.code),
                    latency: Date().timeIntervalSince(start)
                )
            }

            return response
        } catch {
            // Log exceptions (except excluded routes)
            if !shouldSkipLogging {
                await logError(
                    request: request,
                    statusCode: 500,
                    error: error,
                    latency: Date().timeIntervalSince(start)
                )
            }

            // API — rethrow the error for JSON response
            throw error
        }
    }

    private func logError(
        request: Request,
        statusCode: Int,
        error: Error? = nil,
        latency: TimeInterval
    ) async {
        do {
            let supabaseWrapper = try request.application.supabaseWrapper

            let message = ErrorLogger.createLogMessage(
                method: request.method.rawValue,
                path: request.url.path,
                statusCode: statusCode,
                latency: latency,
                error: error
            )

            // Use the logging system via SupabaseWrapper
            supabaseWrapper.log(level: .error, message: message)

        } catch {
            request.logger.warning("❌ Failed to initialize SupabaseWrapper for logging: \(error.localizedDescription)")
        }
    }
}
