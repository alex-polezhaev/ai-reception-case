// ErrorLogger: shared error-logging helper with route exclusion.
import Foundation

public struct ErrorLogger {
    /// Routes excluded from logging
    private static let excludedRoutes: Set<String> = [
        "/favicon.ico",
    ]

    public static func shouldSkipLogging(method: String, path: String) -> Bool {
        return method == "GET" && excludedRoutes.contains(path)
    }

    public static func createLogMessage(
        method: String,
        path: String,
        statusCode: Int,
        latency: TimeInterval,
        error: Error? = nil
    ) -> String {
        let errorMessage = error != nil ? String(reflecting: error!) : ""

        return "[\(method)] \(path) → \(statusCode) " +
            "(\(String(format: "%.2f", latency * 1000)) ms)" +
            (errorMessage.isEmpty ? "" : " — \(errorMessage)")
    }
}
