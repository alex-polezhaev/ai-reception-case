// MiniAppViewController: renders the Telegram Mini App pages (devices list, device detail, sessions).
import JWT
import Leaf
import Shared
import Supabase
import Vapor

struct MiniAppViewController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Route group with Telegram authorization
        let ui = routes.grouped(TelegramAuthMiddleware())

        ui.get("devices", use: devicesHandler)
        ui.get("devices", "add", use: addDeviceHandler)
        ui.post("devices", "add", use: addDevicePostHandler)
        ui.get("devices", ":device_id", use: deviceHandler)
        ui.get("devices", ":device_id", "sessions", use: deviceSessionsHandler)
        ui.get("devices", ":device_id", "sessions", ":session_id", use: sessionDetailHandler)
    }

    func devicesHandler(req: Request) async throws -> View {
        let context = try await DevicesPageContext.load(req: req)
        return try await req.view.render("devices", context)
    }

    func deviceHandler(req: Request) async throws -> View {
        guard let deviceId = req.parameters.get("device_id") else {
            throw Abort(.badRequest, reason: "Device ID required")
        }

        let context = try await DevicePageContext.load(req: req, deviceId: deviceId)
        return try await req.view.render("device", context)
    }

    func deviceSessionsHandler(req: Request) async throws -> View {
        let context = try await DeviceSessionsPageContext.load(req: req)
        return try await req.view.render("device-sessions", context)
    }

    func sessionDetailHandler(req: Request) async throws -> View {
        let context = try await SessionDetailPageContext.load(req: req)
        return try await req.view.render("session-detail", context)
    }


    func addDeviceHandler(req: Request) async throws -> View {
        let context = try await AddDevicePageContext.load(req: req)
        return try await req.view.render("add-device", context)
    }

    func addDevicePostHandler(req: Request) async throws -> View {
        do {
            let result = try await AddDevicePageContext.processAddDevice(req: req)

            let successContext = [
                "type": "success",
                "message": result.message,
                "redirectTo": "/devices",
                "redirectDelay": "2000"
            ]

            return try await req.view.render("form-response", successContext)

        } catch let error as AbortError {
            let errorContext = [
                "type": "error",
                "message": error.reason
            ]

            return try await req.view.render("form-response", errorContext)
        }
    }
}
