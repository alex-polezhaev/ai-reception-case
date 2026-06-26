// TelegramAuthMiddleware: validates Telegram Mini App init data and authenticates the request.
import Vapor
import Crypto
import Foundation
import Shared
import Leaf

extension Request {
    var telegramUser: TelegramUser? {
        get { storage[TelegramUserKey.self] }
        set { storage[TelegramUserKey.self] = newValue }
    }
}

private struct TelegramUserKey: StorageKey {
    typealias Value = TelegramUser
}

struct TelegramAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        var initData: String?

        // Try cookie first
        if let cookieData = request.cookies["telegram_init_data"]?.string {
            initData = cookieData
        }
        // No cookie — try query parameter (first login)
        else if let queryData = request.query[String.self, at: "initData"] {
            initData = queryData
        }

        guard let initDataString = initData else {
            return try await showInitializationPage(req: request)
        }

        // Validate and parse data
        guard let user = try validateTelegramInitData(initDataString, req: request) else {
            return try await showInitializationPage(req: request)
        }

        request.telegramUser = user

        // Get response
        let response = try await next.respond(to: request)

        // Set cookie if it was not present
        if request.cookies["telegram_init_data"] == nil {
            response.cookies["telegram_init_data"] = HTTPCookies.Value(
                string: initDataString,
                expires: Date().addingTimeInterval(3600), // 1 hour
                maxAge: 3600,
                domain: nil,
                path: "/",
                isSecure: request.application.environment != .development,
                isHTTPOnly: false, // Allow JavaScript access
                sameSite: .lax
            )
        }

        return response
    }

    private func validateTelegramInitData(_ initDataRaw: String, req: Request) throws -> TelegramUser? {
        let botToken = Environment.get("TELEGRAM_BOT_TOKEN") ?? ""

        guard let urlComponents = URLComponents(string: "?" + initDataRaw),
              let queryItems = urlComponents.queryItems
        else {
            return nil
        }

        var dataDict: [String: String] = [:]
        var hash = ""

        for item in queryItems {
            if let value = item.value {
                if item.name == "hash" {
                    hash = value
                } else {
                    dataDict[item.name] = value
                }
            }
        }

        guard !hash.isEmpty else { return nil }

        let sortedKeys = dataDict.keys.sorted()
        let dataString = sortedKeys.map { "\($0)=\(dataDict[$0] ?? "")" }.joined(separator: "\n")

        guard validateSignature(dataString: dataString, hash: hash, botToken: botToken) else {
            return nil
        }

        // Check timestamp (1 hour max age)
        if let authDateString = dataDict["auth_date"],
           let authDate = Int64(authDateString)
        {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let maxAge: Int64 = 3600

            if currentTime - authDate > maxAge {
                return nil
            }
        }

        guard let userString = dataDict["user"],
              let userData = userString.data(using: .utf8)
        else {
            req.logger.warning("User data not found. Available keys: \(dataDict.keys)")
            return nil
        }

        do {
            return try JSONDecoder().decode(TelegramUser.self, from: userData)
        } catch {
            req.logger.error("Failed to decode user data: \(error)")
            return nil
        }
    }

    private func validateSignature(dataString: String, hash: String, botToken: String) -> Bool {
        let secretKey = SymmetricKey(data: Data("WebAppData".utf8))
        let tokenData = Data(botToken.utf8)
        let hmac1 = HMAC<SHA256>.authenticationCode(for: tokenData, using: secretKey)

        let dataStringData = Data(dataString.utf8)
        let finalKey = SymmetricKey(data: Data(hmac1))
        let hmac2 = HMAC<SHA256>.authenticationCode(for: dataStringData, using: finalKey)

        let calculatedHash = Data(hmac2).map { String(format: "%02hhx", $0) }.joined()

        return calculatedHash == hash
    }

    private func showInitializationPage(req: Request) async throws -> Response {
        let view = try await req.view.render("telegram-init")

        return Response(
            status: .ok,
            headers: HTTPHeaders([("content-type", "text/html; charset=utf-8")]),
            body: Response.Body(buffer: view.data)
        )
    }
}
