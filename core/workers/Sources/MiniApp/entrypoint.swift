// MiniApp entrypoint: loads environment, configures and runs the Telegram Mini App Vapor server.
import Logging
import NIOCore
import NIOPosix
import Vapor
import Shared

@main
enum Entrypoint {
    static func main() async throws {
        let app = try await Application.make()

        loadEnv()

        do {
            try await configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }
}
