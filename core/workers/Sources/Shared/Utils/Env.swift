// Environment loading and typed access to environment variables.
import Foundation

enum EnvError: Error {
    case notFound(key: String)
    case decodingFailed(key: String, value: String, type: Any.Type)
}

public func env<T: LosslessStringConvertible>(_ key: String, as type: T.Type) throws -> T {
    guard let value = ProcessInfo.processInfo.environment[key] else {
        print("ENV: \(key) not found")
        throw EnvError.notFound(key: key)
    }

    guard let result = T(value) else {
        print("ENV: Failed to decode \(key) as \(T.self)")
        throw EnvError.decodingFailed(key: key, value: value, type: T.self)
    }

    return result
}

public func loadEnv() {
    #if DEBUG
    let envFile = ".env.dev"
    #else
    let envFile = ".env"
    #endif

    let possiblePaths = [
        envFile,
        "../\(envFile)",
        "../../\(envFile)",
    ]

    var content: String?
    var foundPath: String?

    for path in possiblePaths {
        if let envContent = try? String(contentsOfFile: path, encoding: .utf8) {
            content = envContent
            foundPath = path
            break
        }
    }

    guard let envContent = content else {

        for path in possiblePaths {
            print("  - \(path)")
        }

        fatalError("ENV: \(envFile) not found in any of these paths")
    }

    print("ENV: Loading \(envFile) from \(foundPath!)")

    let lines = envContent.components(separatedBy: .newlines)
    var count = 0

    for line in lines {
        var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty || trimmed.hasPrefix("#") {
            continue
        }

        if let commentRange = trimmed.range(of: "#") {
            trimmed = String(trimmed[..<commentRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let parts = trimmed.components(separatedBy: "=")
        if parts.count >= 2 {
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)

            setenv(key, value, 1)
            count += 1
        }
    }

    print("ENV: Loaded \(count) variables")
}
