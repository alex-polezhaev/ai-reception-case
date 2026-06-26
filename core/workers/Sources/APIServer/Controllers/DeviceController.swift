// DeviceController: device API endpoints (boot, audio upload, silence reporting, log ingestion).
import Foundation
import JWT
import Shared
import Vapor

// MARK: - Response Models

struct DeviceBootResponse: Content {
    let jwt: String
    let time: Int
}

// MARK: - JWT Payload

struct DevicePayload: JWTPayload {
    let device_id: String

    func verify(using algorithm: some JWTAlgorithm) async throws {
    }
}

// MARK: - Device Controller

struct DeviceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let devices = routes.grouped("device")

        // Boot endpoint
        devices.get("boot", ":deviceid", use: boot)

        // Upload endpoint
        devices.on(.POST, "upload", ":deviceid", body: .stream, use: upload)

        // Silence endpoint
        devices.post("silence", ":deviceid", use: silence)

        // Log endpoint
        devices.post("log", ":deviceid", use: log)
    }

    // MARK: - Boot Device

    @Sendable
    func boot(req: Request) async throws -> DeviceBootResponse {
        let supabaseWrapper = try req.application.supabaseWrapper
        let supabase = supabaseWrapper.client

        guard let deviceId = req.parameters.get("deviceid") else {
            throw Abort(.badRequest, reason: "deviceid missing")
        }

        supabaseWrapper.log(level: .info, message: "Device boot request for deviceId: \(deviceId)")

        // Fetch device from Supabase
        let device: Shared.Device = try await supabase
            .from("devices")
            .select()
            .eq("id", value: deviceId)
            .single()
            .execute()
            .value

        let payload = DevicePayload(device_id: device.id)
        let jwt = try await req.jwt.sign(payload)

        let timestamp = Int(Date().timeIntervalSince1970)

        // Mark device boot and update last_active_at
        let isoFormatter = ISO8601DateFormatter()
        let timestampString = isoFormatter.string(from: Date())

        var updateFields: [String: String] = [
            "boot_at": timestampString,
            "last_active_at": timestampString
        ]

        // Fill activated_at on first boot if not set
        if device.activated_at == nil {
            updateFields["activated_at"] = timestampString
        }

        try await supabase
            .from("devices")
            .update(updateFields)
            .eq("id", value: deviceId)
            .execute()

        supabaseWrapper.log(level: .info, message: "Device \(deviceId) booted successfully")

        return DeviceBootResponse(jwt: jwt, time: timestamp)
    }

    // MARK: - Upload Audio

    @Sendable
    func upload(req: Request) async throws -> Response {
        let supabaseWrapper = try req.application.supabaseWrapper
        let supabase = supabaseWrapper.client

        guard let deviceId = req.parameters.get("deviceid") else {
            throw Abort(.badRequest, reason: "Deviceid missing")
        }

        // JWT authorization
        guard let authHeader = req.headers.first(name: "Authorization"),
              authHeader.hasPrefix("Bearer ") else {
            throw Abort(.unauthorized, reason: "Authorization header missing or invalid")
        }

        let token = String(authHeader.dropFirst(7)) // Strip "Bearer "
        let payload = try await req.jwt.verify(token, as: DevicePayload.self)

        // Verify device_id in token matches URL parameter
        guard payload.device_id == deviceId else {
            throw Abort(.forbidden, reason: "Device ID mismatch")
        }

        guard let rawTimestamp = req.headers.first(name: "X-Timestamp"),
              let timestampValue = Double(rawTimestamp)
        else {
            throw Abort(.badRequest, reason: "X-Timestamp header missing or invalid")
        }
        let timestamp = Date(timeIntervalSince1970: timestampValue)

        supabaseWrapper.log(level: .info, message: "Processing audio upload from device \(deviceId), timestamp: \(timestamp)")

        // Verify device

        let device = try await supabase
            .from("devices")
            .select()
            .eq("id", value: deviceId)
            .single()
            .execute()
            .value as Shared.Device

        // Collect PCM data
        var audioData = Data()
        for try await chunk in req.body {
            if let data = chunk.getData(at: 0, length: chunk.readableBytes) {
                audioData.append(data)
            }
        }

        // Size validation: sample_rate * AudioConfig.channels * (bits_per_sample / 8) * duration
        let expectedBytes = AudioConfig.sampleRate * AudioConfig.channels * (AudioConfig.bitsPerSample / 8) * Int(AudioConfig.expectedDurationSeconds)
        guard audioData.count == expectedBytes else {
            throw Abort(.badRequest, reason: "Invalid PCM size: expected \(expectedBytes), got \(audioData.count)")
        }

        // Format validation: size must be a multiple of sample size
        let bytesPerSample = (AudioConfig.bitsPerSample / 8) * AudioConfig.channels
        guard audioData.count % bytesPerSample == 0 else {
            throw Abort(.badRequest, reason: "Invalid PCM format")
        }

        // Process through Silero VAD FIRST
        let vadService = try SileroVADService()
        let vadTimeline = try await vadService.processAudio(audioData: audioData, on: req)

        // No voice activity — create SilenceChunk and return OK
        guard vadTimeline.contains(1) else {
            // Increment bad_vad_count by 1
            let newBadVadCount = device.bad_vad_count + 1
            let isoFormatter = ISO8601DateFormatter()
            let lastActiveString = isoFormatter.string(from: Date())

            // Create SilenceChunk
            let silenceChunk = SilenceChunk(
                id: nil,
                timestamp: timestamp,
                device_id: deviceId
            )

            // Update device and create SilenceChunk in parallel
            async let deviceUpdate = supabase
                .from("devices")
                .update([
                    "bad_vad_count": String(newBadVadCount),
                    "last_active_at": lastActiveString
                ])
                .eq("id", value: deviceId)
                .execute()

            async let silenceInsert = supabase
                .from("silence_chunks")
                .upsert(silenceChunk, onConflict: "device_id,timestamp")
                .execute()

            // Wait for both operations to complete
            let _ = try await deviceUpdate
            let _ = try await silenceInsert

            supabaseWrapper.log(level: .info, message: "No voice activity detected for device \(deviceId), bad_vad_count: \(newBadVadCount), silence recorded")

            return Response(status: .ok, body: .init(string: "OK - No voice activity detected"))
        }

        // Generate S3 key
        let timestampString = String(Int(timestamp.timeIntervalSince1970))
        let s3Key = "\(deviceId)/\(timestampString).pcm"

        // Upload to S3 ONLY if voice activity is present
        let bucketName = try env("S3_DEVICE_PCM_BUCKET", as: String.self)
        try await req.application.s3.upload(bucket: bucketName, key: s3Key, data: audioData)

        // Create DB record with VAD result
        let duration = Double(audioData.count) / Double(AudioConfig.sampleRate * AudioConfig.channels * (AudioConfig.bitsPerSample / 8))

        let newChunk = PcmChunk(
            id: nil,
            s3_key: s3Key,
            timestamp: timestamp,
            duration: Int(duration),
            device_id: deviceId,
            vad_timeline: vadTimeline // Store the actual voice-activity array
        )

        let _ = try await supabase
            .from("pcm_chunks")
            .upsert(newChunk, onConflict: "s3_key")
            .single()
            .execute()
            .value

        // Update last_active_at
        let isoFormatter = ISO8601DateFormatter()
        let lastActiveString = isoFormatter.string(from: Date())

        try await supabase
            .from("devices")
            .update(["last_active_at": lastActiveString])
            .eq("id", value: deviceId)
            .execute()

        supabaseWrapper.log(level: .info, message: "Successfully processed audio upload for device \(deviceId), S3 key: \(s3Key), duration: \(duration)s")

        return Response(status: .ok, body: .init(string: "OK"))
    }

    // MARK: - Record Silence

    @Sendable
    func silence(req: Request) async throws -> Response {
        let supabaseWrapper = try req.application.supabaseWrapper
        let supabase = supabaseWrapper.client

        guard let deviceId = req.parameters.get("deviceid") else {
            throw Abort(.badRequest, reason: "deviceid missing")
        }

        // JWT authorization
        guard let authHeader = req.headers.first(name: "Authorization"),
              authHeader.hasPrefix("Bearer ") else {
            throw Abort(.unauthorized, reason: "Authorization header missing or invalid")
        }

        let token = String(authHeader.dropFirst(7))
        let payload = try await req.jwt.verify(token, as: DevicePayload.self)

        guard payload.device_id == deviceId else {
            throw Abort(.forbidden, reason: "Device ID mismatch")
        }

        guard let rawTimestamp = req.headers.first(name: "X-Timestamp"),
              let timestampValue = Double(rawTimestamp)
        else {
            throw Abort(.badRequest, reason: "X-Timestamp header missing or invalid")
        }
        let timestamp = Date(timeIntervalSince1970: timestampValue)

        supabaseWrapper.log(level: .info, message: "Recording silence for device \(deviceId), timestamp: \(timestamp)")

        // Create SilenceChunk
        let silenceChunk = SilenceChunk(
            id: nil,
            timestamp: timestamp,
            device_id: deviceId
        )

        try await supabase
            .from("silence_chunks")
            .upsert(silenceChunk, onConflict: "device_id,timestamp")
            .execute()

        // Update last_active_at
        let isoFormatter = ISO8601DateFormatter()
        let lastActiveString = isoFormatter.string(from: Date())

        try await supabase
            .from("devices")
            .update(["last_active_at": lastActiveString])
            .eq("id", value: deviceId)
            .execute()

        supabaseWrapper.log(level: .info, message: "Successfully recorded silence for device \(deviceId)")

        return Response(status: .ok, body: .init(string: "OK"))
    }

    // MARK: - Log Endpoint

    @Sendable
    func log(req: Request) async throws -> Response {
        let supabaseWrapper = try req.application.supabaseWrapper
        let supabase = supabaseWrapper.client

        guard let deviceId = req.parameters.get("deviceid") else {
            throw Abort(.badRequest, reason: "deviceid missing")
        }

        // JWT authorization
        guard let authHeader = req.headers.first(name: "Authorization"),
              authHeader.hasPrefix("Bearer ") else {
            throw Abort(.unauthorized, reason: "Authorization header missing or invalid")
        }

        let token = String(authHeader.dropFirst(7))
        let payload = try await req.jwt.verify(token, as: DevicePayload.self)

        guard payload.device_id == deviceId else {
            throw Abort(.forbidden, reason: "Device ID mismatch")
        }

        // Parse body to get level and message
        struct LogRequest: Content {
            let level: AppLogLevel
            let message: String
        }

        let logRequest = try req.content.decode(LogRequest.self)

        // Create AppLog with device_id as source
        let appLog = AppLog(
            level: logRequest.level,
            timestamp: Date(),
            source: deviceId,
            message: logRequest.message
        )

        try await supabase
            .from("logs")
            .insert(appLog)
            .execute()

        // Update last_active_at
        let isoFormatter = ISO8601DateFormatter()
        let lastActiveString = isoFormatter.string(from: Date())

        try await supabase
            .from("devices")
            .update(["last_active_at": lastActiveString])
            .eq("id", value: deviceId)
            .execute()

        supabaseWrapper.log(level: .info, message: "Successfully logged for device \(deviceId): [\(logRequest.level)] \(logRequest.message)")

        return Response(status: .ok, body: .init(string: "OK"))
    }
}
