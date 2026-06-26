// APIServer configuration: HTTP port, JWT, Leaf and middleware setup for the device API.
import JWT
import Leaf
import Shared
import Supabase
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    app.http.server.configuration.port = 8080

    // Configure JWT
    let jwtSecret = try env("JWT_SECRET", as: String.self)

    // Add HMAC with SHA-256 signer
    await app.jwt.keys.add(hmac: HMACKey(from: jwtSecret), digestAlgorithm: .sha256)

    // Server configuration
    app.http.server.configuration.hostname = "0.0.0.0"

    // JSON decoder configuration
    let customDecoder = JSONDecoder()
    customDecoder.dateDecodingStrategy = .secondsSince1970
    ContentConfiguration.global.use(decoder: customDecoder, for: .json)

    // Middleware
    app.middleware.use(ErrorApiMiddleware())

    // Register routes
    try routes(app)
}

// MARK: Supabase singleton

extension Application {
    var supabaseWrapper: SupabaseWrapper {
        get throws {
            if let cached = storage[SupabaseWrapperKey.self] {
                return cached
            }
            let client = try SupabaseWrapper(source: "api-server")
            storage[SupabaseWrapperKey.self] = client
            return client
        }
    }

    private struct SupabaseWrapperKey: StorageKey {
        typealias Value = SupabaseWrapper
    }
}

// MARK: S3 singleton

extension Application {
    var s3: S3Wrapper {
        get throws {
            if let cached = storage[S3Key.self] {
                return cached
            }
            let wrapper = try S3Wrapper()
            storage[S3Key.self] = wrapper
            return wrapper
        }
    }

    private struct S3Key: StorageKey {
        typealias Value = S3Wrapper
    }
}
