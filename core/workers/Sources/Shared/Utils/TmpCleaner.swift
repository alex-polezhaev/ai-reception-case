// Temporary-file helpers: write Data to temp files and clean them up.
import Foundation

public extension Data {
    func writeToTemp(withExtension ext: String) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try self.write(to: tempURL)
        return tempURL
    }
}

public func cleanTempDirectory(ext: String) {
    let tempDir = FileManager.default.temporaryDirectory

    do {
        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)

        for file in contents {
            guard file.pathExtension.lowercased() == ext.lowercased() else { continue }

            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                try FileManager.default.removeItem(at: file)
            }
        }

    } catch {
        print("⚠️ Failed to clean temp .\(ext) files: \(error)")
    }
}
