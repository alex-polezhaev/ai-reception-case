// processTimeline: detects speech sessions in a device timeline and persists/enqueues downstream work.
import Foundation
import Shared
import Supabase

func processTimeline(
    timeline: Timeline,
    deviceId: String,
    config: VadConfig,
    supabase: SupabaseClient,
    supabaseWrapper: SupabaseWrapper
) async throws -> Timeline {
    guard !timeline.isEmpty else { return [] }

    let activeRegions = timeline.activeRegions(
        activityWindow: config.activityWindow,
        activityThreshold: config.activityThreshold
    )

    // S3 configuration
    let s3 = try S3Wrapper()
    let bucket = try env("S3_INCOMPLETE_TIMELINE_BUCKET", as: String.self)
    let key = "\(deviceId).json"

    // No active regions — clean S3 and set NULL
    guard !activeRegions.isEmpty else {
        try? await s3.delete(bucket: bucket, key: key)

        let patch: [String: Date?] = ["incomplete_timestamp": nil]
        try await supabase
            .from("devices")
            .update(patch)
            .eq("id", value: deviceId)
            .execute()

        return []
    }

    // Split into sessions
    let result = try activeRegions.sessions(
        endSilenceDuration: config.endSilenceDuration,
        minSessionLength: config.minSessionLength
    )

    if !result.completed.isEmpty {
        supabaseWrapper.log(level: .info, message: "Created \(result.completed.count) sessions")
    }

    // Save completed sessions
    for session in result.completed {
        let beautified = session
            .trimEdges()
            .trimInnerSilence(
                maxInnerSilence: config.maxInnerSilence,
                minSilenceToTrim: config.minSilenceToTrim
            )

        let vadSession = try await VadSession(
            timeline: beautified,
            deviceId: deviceId,
            supabaseWrapper: supabaseWrapper
        )

        try await supabase
            .from("vad_sessions")
            .upsert(vadSession, onConflict: "s3_key")
            .execute()
    }

    // Save or delete incomplete timeline and update timestamp
    let timestamp: Date? = result.incomplete.isEmpty ? nil : Date()

    if result.incomplete.isEmpty {
        try? await s3.delete(bucket: bucket, key: key)
    } else {
        let jsonData = try JSONEncoder().encode(result.incomplete)
        try await s3.upload(bucket: bucket, key: key, data: jsonData)
    }

    let patch: [String: Date?] = ["incomplete_timestamp": timestamp]
    try await supabase
        .from("devices")
        .update(patch)
        .eq("id", value: deviceId)
        .execute()

    return result.incomplete
}
