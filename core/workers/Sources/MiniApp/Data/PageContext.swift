// PageContext: Leaf view-context models for the Mini App pages.
import Shared
import Supabase
import Vapor

// MARK: - Devices Page

struct DevicesPageContext: Content {
    let devices: [DeviceView]
    let totalDevices: Int
    let userName: String?

    struct DeviceView: Content, Sendable {
        let id: String
        let title: String
        let isActive: Bool
        let lastActivity: String
    }

    static func load(req: Request) async throws -> DevicesPageContext {
        guard let user = req.telegramUser else {
            throw Abort(.unauthorized)
        }

        let supabaseWrapper = try req.application.supabaseWrapper
        let supabase = supabaseWrapper.client

        let account = try await TelegramAccount.findOrCreate(supabase: supabase, telegramUser: user)

        let deviceIds = try await account.getDeviceIds(supabase: supabase)

        let devices: [Device] = deviceIds.isEmpty ? [] : try await supabase
            .from("devices")
            .select()
            .in("id", values: deviceIds)
            .execute()
            .value

        let deviceViews = devices.map { device in
            DeviceView(
                id: device.id,
                title: device.title ?? "Device",
                isActive: DateUtils.isDeviceActive(device.last_active_at),
                lastActivity: DateUtils.formatLastActivity(device.last_active_at)
            )
        }

        return DevicesPageContext(
            devices: deviceViews,
            totalDevices: deviceViews.count,
            userName: user.firstName
        )
    }
}

// MARK: - Device Page

struct DevicePageContext: Content {
    let device: DeviceView?
    let userName: String?

    struct DeviceView: Content {
        let id: String
        let title: String
        let isActive: Bool
        let lastActivity: String
    }

    static func load(req: Request, deviceId: String) async throws -> DevicePageContext {
        guard let user = req.telegramUser else {
            throw Abort(.unauthorized)
        }

        let supabaseWrapper = try req.application.supabaseWrapper
        let supabase = supabaseWrapper.client

        let account = try await TelegramAccount.findOrCreate(supabase: supabase, telegramUser: user)

        let hasAccess = try await account.hasDevice(supabase: supabase, deviceId: deviceId)
        guard hasAccess else {
            throw Abort(.forbidden, reason: "Access denied to this device")
        }

        let devices: [Device] = try await supabase
            .from("devices")
            .select()
            .eq("id", value: deviceId)
            .execute()
            .value

        let deviceView = devices.first.map { device in
            DeviceView(
                id: device.id,
                title: device.title ?? "Device",
                isActive: DateUtils.isDeviceActive(device.last_active_at),
                lastActivity: DateUtils.formatLastActivity(device.last_active_at)
            )
        }

        return DevicePageContext(
            device: deviceView,
            userName: user.firstName
        )
    }
}

// MARK: - Device Sessions Page

struct DeviceSessionsPageContext: Content {
    let device: DeviceView?
    let dayGroups: [DeviceSessionDayGroup]
    let totalSessions: Int
    let dateFrom: String
    let dateTo: String
    let currentPeriod: String?

    struct DeviceView: Content {
        let id: String
        let title: String
        let isActive: Bool
        let lastActivity: String
    }

    struct DeviceSessionDayGroup: Codable {
        let date: String
        let sessions: [DeviceSessionView]
    }

    struct DeviceSessionView: Codable {
        let id: String
        let title: String
        let time: String
        let duration: String
        let type: String?
        let keywords: [String]
        let hasAudio: Bool
        let wordCount: Int?
        let isRead: Bool
    }

    static func load(req: Request) async throws -> DeviceSessionsPageContext {
        guard let user = req.telegramUser else {
            throw Abort(.unauthorized)
        }

        guard let deviceId = req.parameters.get("device_id") else {
            throw Abort(.badRequest, reason: "Device ID required")
        }

        let supabaseWrapper = try req.application.supabaseWrapper
        let supabase = supabaseWrapper.client

        let account = try await TelegramAccount.findOrCreate(supabase: supabase, telegramUser: user)

        let hasAccess = try await account.hasDevice(supabase: supabase, deviceId: deviceId)
        guard hasAccess else {
            throw Abort(.forbidden, reason: "Access denied to this device")
        }

        let (fromDate, toDate, currentPeriod) = parseDateFilter(req: req)

        let sessions: [VadSession] = try await supabase
            .from("vad_sessions")
            .select()
            .eq("device_id", value: deviceId)
            .neq("is_unsuitable", value: true)
            .gte("timestamp", value: "\(fromDate)T00:00:00Z")
            .lt("timestamp", value: "\(toDate)T23:59:59Z")
            .order("timestamp", ascending: false)
            .execute()
            .value

        // Fetch all analysis and transcription data in a single query
        let sessionIds = sessions.compactMap { $0.id }.map(String.init)

        let analyses: [VadAnalysis] = sessionIds.isEmpty ? [] : try await supabase
            .from("vad_analysis")
            .select()
            .in("vad_session_id", values: sessionIds)
            .execute()
            .value

        let transcriptions: [VadTranscription] = sessionIds.isEmpty ? [] : try await supabase
            .from("vad_transcriptions")
            .select()
            .in("vad_session_id", values: sessionIds)
            .execute()
            .value

        // Build lookup maps
        let analysisMap = Dictionary(uniqueKeysWithValues: analyses.map { (String($0.vad_session_id), $0) })
        let transcriptionMap = Dictionary(uniqueKeysWithValues: transcriptions.map { (String($0.vad_session_id), $0) })

        // Group by day
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Moscow")!

        let grouped = Dictionary(grouping: sessions) { session in
            formatter.string(from: session.timestamp)
        }

        let dayGroups = grouped.map { date, sessions in
            let sessionViews = sessions.sorted { $0.timestamp < $1.timestamp }.map { session in
                let sessionId = String(session.id ?? 0)
                let analysis = analysisMap[sessionId]
                let transcription = transcriptionMap[sessionId]

                let title: String
                if let analysis = analysis, !analysis.title.isEmpty {
                    title = analysis.title
                } else if transcription != nil {
                    title = "Analysis in progress"
                } else {
                    title = "Transcription in progress"
                }

                let wordCount = transcription?.text.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }.count

                return DeviceSessionView(
                    id: sessionId,
                    title: title,
                    time: DateUtils.formatTime(session.timestamp),
                    duration: DateUtils.formatDuration(session.duration),
                    type: analysis?.type,
                    keywords: Array((analysis?.keywords ?? [String]()).prefix(3)),
                    hasAudio: !session.s3_key.isEmpty,
                    wordCount: wordCount,
                    isRead: session.is_read ?? false
                )
            }

            return DeviceSessionDayGroup(date: date, sessions: sessionViews)
        }.sorted { $0.date < $1.date }

        let devices: [Device] = try await supabase
            .from("devices")
            .select()
            .eq("id", value: deviceId)
            .execute()
            .value

        let deviceView = devices.first.map { device in
            DeviceView(
                id: device.id,
                title: device.title ?? "Device",
                isActive: DateUtils.isDeviceActive(device.last_active_at),
                lastActivity: DateUtils.formatLastActivity(device.last_active_at)
            )
        }

        return DeviceSessionsPageContext(
            device: deviceView,
            dayGroups: dayGroups,
            totalSessions: sessions.count,
            dateFrom: fromDate,
            dateTo: toDate,
            currentPeriod: currentPeriod
        )
    }

    private static func parseDateFilter(req: Request) -> (String, String, String?) {
        if let period = req.query[String.self, at: "period"] {
            let dates = DateUtils.getDateRangeForPeriod(period)
            return (dates.from, dates.to, period)
        }

        let fromDate = req.query[String.self, at: "dateFrom"] ?? DateUtils.getCurrentDateString(daysAgo: 7)
        let toDate = req.query[String.self, at: "dateTo"] ?? DateUtils.getCurrentDateString(daysAgo: 0)

        return (fromDate, toDate, nil)
    }
}

// MARK: - Session Detail Page

struct SessionDetailPageContext: Content {
    let session: SessionDetailView
    let title: String?

    struct SessionDetailView: Content, Sendable {
        let id: String
        let title: String
        let date: String
        let time: String
        let duration: String
        let deviceName: String
        let type: String
        let keywords: [String]
        let products: [String]
        let quality: Int?
        let qualityStars: Int?
        let optimizedText: String?
        let fullTranscription: String
        let audioUrl: String?
        let hasAudio: Bool
    }

    static func load(req: Request) async throws -> SessionDetailPageContext {
        guard let user = req.telegramUser else {
            throw Abort(.unauthorized)
        }

        guard let sessionId = req.parameters.get("session_id") else {
            throw Abort(.badRequest, reason: "Session ID required")
        }

        let supabaseWrapper = try req.application.supabaseWrapper
        let supabase = supabaseWrapper.client

        let account = try await TelegramAccount.findOrCreate(supabase: supabase, telegramUser: user)

        let session: VadSession
        do {
            let sessions: [VadSession] = try await supabase
                .from("vad_sessions")
                .select()
                .eq("id", value: sessionId)
                .neq("is_unsuitable", value: true)
                .execute()
                .value

            guard let firstSession = sessions.first else {
                throw Abort(.notFound, reason: "Session not found")
            }
            session = firstSession
        } catch {
            throw Abort(.notFound, reason: "Session not found")
        }

        let hasAccess = try await account.hasDevice(supabase: supabase, deviceId: session.device_id)
        guard hasAccess else {
            throw Abort(.forbidden, reason: "Access denied to this session")
        }

        if session.is_read == nil || session.is_read == false {
            try await supabase
                .from("vad_sessions")
                .update(["is_read": true])
                .eq("id", value: sessionId)
                .execute()
        }

        let devices: [Device] = try await supabase
            .from("devices")
            .select()
            .eq("id", value: session.device_id)
            .execute()
            .value

        let deviceName = devices.first?.title ?? "Unknown device"

        let transcriptions: [VadTranscription] = try await supabase
            .from("vad_transcriptions")
            .select()
            .eq("vad_session_id", value: sessionId)
            .execute()
            .value

        let fullTranscription = transcriptions.first?.text ?? "Transcription unavailable"

        let analyses: [VadAnalysis] = try await supabase
            .from("vad_analysis")
            .select()
            .eq("vad_session_id", value: sessionId)
            .execute()
            .value

        let analysis = analyses.first

        var audioUrl: String?
        let hasAudio = !session.s3_key.isEmpty

        if hasAudio {
            let s3 = try req.application.s3

            let bucket = try env("S3_SESSIONS_WAV_BUCKET", as: String.self)
            let signedURL = try await s3.signedUrl(
                bucket: bucket,
                key: session.s3_key,
                method: .GET,
                expiresInSec: 3600
            )
            audioUrl = signedURL.absoluteString
        }

        let sessionDetail = SessionDetailView(
            id: sessionId,
            title: analysis?.title ?? "Recording \(DateUtils.formatTime(session.timestamp))",
            date: DateUtils.formatDate(session.timestamp),
            time: DateUtils.formatTime(session.timestamp),
            duration: DateUtils.formatDuration(session.duration),
            deviceName: deviceName,
            type: analysis?.type ?? "unknown",
            keywords: analysis?.keywords ?? [],
            products: analysis?.products ?? [],
            quality: analysis?.quality,
            qualityStars: DateUtils.calculateQualityStars(analysis?.quality),
            optimizedText: analysis?.optimized_text,
            fullTranscription: fullTranscription,
            audioUrl: audioUrl,
            hasAudio: hasAudio
        )

        return SessionDetailPageContext(
            session: sessionDetail,
            title: sessionDetail.title
        )
    }
}

// MARK: - Add Device Page

struct AddDevicePageContext: Content {
    let title: String
    let userName: String?

    struct MessageResponse: Content {
        let success: Bool
        let message: String
    }

    static func load(req: Request) async throws -> AddDevicePageContext {
        guard let user = req.telegramUser else {
            throw Abort(.unauthorized)
        }

        return AddDevicePageContext(
            title: "Add device",
            userName: user.firstName
        )
    }

    static func processAddDevice(req: Request) async throws -> MessageResponse {
        guard let user = req.telegramUser else {
            throw Abort(.unauthorized)
        }

        struct AddDeviceRequest: Content {
            let deviceCode: String
            let deviceName: String
        }

        let addRequest = try req.content.decode(AddDeviceRequest.self)

        guard !addRequest.deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Device name is required")
        }

        guard addRequest.deviceCode.count >= 4 else {
            throw Abort(.badRequest, reason: "Connection code must be at least 4 characters")
        }

        let supabaseWrapper = try req.application.supabaseWrapper
        let supabase = supabaseWrapper.client

        let account = try await TelegramAccount.findOrCreate(supabase: supabase, telegramUser: user)

        let devices: [Device] = try await supabase
            .from("devices")
            .select()
            .eq("id", value: addRequest.deviceCode)
            .execute()
            .value

        guard !devices.isEmpty else {
            throw Abort(.notFound, reason: "No device found with this code")
        }

        let hasAccess = try await account.hasDevice(supabase: supabase, deviceId: addRequest.deviceCode)
        if hasAccess {
            throw Abort(.conflict, reason: "Device already added")
        }

        try await supabase
            .from("devices")
            .update(["title": addRequest.deviceName])
            .eq("id", value: addRequest.deviceCode)
            .execute()

        try await account.addDevice(supabase: supabase, deviceId: addRequest.deviceCode)

        return MessageResponse(success: true, message: "Device successfully added")
    }
}
