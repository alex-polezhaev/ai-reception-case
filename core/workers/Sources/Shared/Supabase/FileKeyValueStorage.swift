// FileKeyValueStorage: file-backed AuthLocalStorage for the Supabase client.
import Supabase
import Foundation

struct FileKeyValueStorage: AuthLocalStorage {
    private let directory: URL

    init(basePath: String = "/tmp/supa-storage") throws {
        self.directory = URL(fileURLWithPath: basePath, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func store(key: String, value: Data) throws {
        let url = directory.appendingPathComponent(sanitize(key))
        try value.write(to: url, options: .atomic)
    }

    func retrieve(key: String) throws -> Data? {
        let url = directory.appendingPathComponent(sanitize(key))
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func remove(key: String) throws {
        let url = directory.appendingPathComponent(sanitize(key))
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func sanitize(_ key: String) -> String {
        // Prevents path traversal and forbidden characters
        return key.replacingOccurrences(of: "/", with: "_")
    }
}

