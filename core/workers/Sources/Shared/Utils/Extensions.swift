// Shared general-purpose extensions.
import Foundation

public extension Int {
    func toString() -> String {
        String(self)
    }
}

public extension Optional where Wrapped == Int {
    func requireID(_ message: String = "Missing ID") throws -> Int {
        guard let value = self else {
            throw NSError(domain: "IDError", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return value
    }
}
