// MiniApp configuration: HTTP port, CORS, Leaf and middleware setup for the Telegram Mini App.
import JWT
import Leaf
import Shared
import Supabase
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    app.http.server.configuration.port = 8081

    // Configure CORS for Mini Apps
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .custom("https://web.telegram.org"),
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

    // Error handling middleware
    app.middleware.use(ErrorUIMiddleware())

    // Server configuration
    app.http.server.configuration.hostname = "0.0.0.0"

    // JSON decoder configuration
    let customDecoder = JSONDecoder()
    customDecoder.dateDecodingStrategy = .secondsSince1970
    ContentConfiguration.global.use(decoder: customDecoder, for: .json)

    // Views - configure Leaf with explicit path
    app.views.use(.leaf)

    // Set the working directory for Leaf templates
    if app.environment != .testing {
        let workingDirectory = app.directory.workingDirectory
        app.leaf.configuration.rootDirectory = workingDirectory + "Resources/Views/"
    }

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
            let client = try SupabaseWrapper(source: "mini-app")
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
