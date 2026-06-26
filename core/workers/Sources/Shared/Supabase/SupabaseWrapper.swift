// SupabaseWrapper: shared Supabase client wrapper with logging.
import Foundation
import Supabase

public class SupabaseWrapper: @unchecked Sendable {
    public let client: SupabaseClient
    public let source: String

    public init(source: String) throws {
        client = try SupabaseClient(
            supabaseURL: URL(string: env("SUPABASE_URL", as: String.self))!,
            supabaseKey: env("SUPABASE_SERVICE_ROLE_KEY", as: String.self),
            options: .init(auth: .init(storage: FileKeyValueStorage()))
        )
        self.source = source
    }
}
