// SupabaseWrapper logging: writes application logs to Supabase (and stdout).
import Foundation
import Supabase

public extension SupabaseWrapper {
    func log(level: AppLogLevel, message: String) {
        let source = self.source
        let client = self.client

        Task.detached(priority: .background) {
            #if DEBUG
                // DEBUG mode
                switch level {
                case .error:
                    await sendToServer(level: level, source: source, message: message)
                    break
                case .info:
                    print(source + "-" + message)
                    break
                }
            #else
                // RELEASE mode
                switch level {
                case .error:
                    // Server only
                    await sendToServer(level: level, source: source, message: message)
                case .info:
                    // Do nothing
                    break
                }
            #endif
        }

        func sendToServer(level: AppLogLevel, source: String, message: String) async {
            do {
                let log = AppLog(
                    level: level,
                    timestamp: Date(),
                    source: source,
                    message: message
                )

                _ = try await client
                    .from("logs")
                    .insert(log)
                    .execute()

            } catch {
                print("❌ Failed to log to Supabase: \(String(reflecting: error))")
            }
        }
    }
}
