// SessionWorker: consumes the session queue, builds device timelines from PCM chunks and detects speech sessions.
import Foundation
import Shared
import Supabase

let workerName = "session-worker"
let queueName = "session-queue"


func mainUseDevice(
    _ supabaseWrapper: SupabaseWrapper
) async throws {
    let supabase = supabaseWrapper.client
    let config = try VadConfig()

    let cutoffTimestamp = Int(Date().timeIntervalSince1970) - config.endSilenceDuration
    let cutoffDate = Date(timeIntervalSince1970: TimeInterval(cutoffTimestamp))

    let devicesWithIncomplete: [Device] = try await supabase
        .from("devices")
        .select()
        .lte("incomplete_timestamp", value: cutoffDate)
        .execute()
        .value

    for expiredDevice in devicesWithIncomplete {
        // Get S3 configuration
        let s3 = try S3Wrapper()
        let bucket = try env("S3_INCOMPLETE_TIMELINE_BUCKET", as: String.self)
        let key = "\(expiredDevice.id).json"

        // Load timeline from S3
        let timeline: Timeline
        do {
            let data = try await s3.download(bucket: bucket, key: key)
            timeline = try JSONDecoder().decode(Timeline.self, from: data)
        } catch {
            // If file not found (404) or decoding error — treat timeline as empty
            continue
        }

        guard !timeline.isEmpty else {
            continue
        }

        supabaseWrapper.log(level: .info, message: "Processing expired timeline: \(expiredDevice.id)")

        _ = try await processTimeline(
            timeline: timeline,
            deviceId: expiredDevice.id,
            config: config,
            supabase: supabase,
            supabaseWrapper: supabaseWrapper
        )

        // Process only the first device with a non-empty timeline
        break
    }
}

func mainUseQueue(
    _ supabaseWrapper: SupabaseWrapper
) async throws {
    let supabase = supabaseWrapper.client
    let config = try VadConfig()

    let task: QueueMessage<SessionMessage> = try await supabase.pgmqGet(queue: queueName, as: SessionMessage.self)

    let pcmChunk: PcmChunk = try await supabase
        .from("pcm_chunks")
        .select()
        .eq("id", value: task.message.pcm_chunk_id)
        .single()
        .execute()
        .value

    // Get S3 configuration
    let s3 = try S3Wrapper()
    let bucket = try env("S3_INCOMPLETE_TIMELINE_BUCKET", as: String.self)
    let key = "\(pcmChunk.device_id).json"

    // Load incomplete timeline from S3
    let incompleteTimeline: Timeline
    do {
        let data = try await s3.download(bucket: bucket, key: key)
        incompleteTimeline = try JSONDecoder().decode(Timeline.self, from: data)
    } catch {
        // If file not found (404) — treat timeline as empty
        incompleteTimeline = []
    }

    let newTimeline = try await pcmChunk.toTimeline()
    let timeline = try await Timeline.merge(
        incomplete: incompleteTimeline,
        new: newTimeline
    )

    _ = try await processTimeline(
        timeline: timeline,
        deviceId: pcmChunk.device_id,
        config: config,
        supabase: supabase,
        supabaseWrapper: supabaseWrapper
    )

    // ACK only after full successful processing
    try await supabase.pgmqAck(queue: queueName, msgId: task.msg_id)
}

Task {
    loadEnv()
    cleanTempDirectory(ext: "wav")

    let supabaseWrapper = try SupabaseWrapper(source: workerName)

    while true {
        do {
            // Priority: process expired devices
            try await mainUseDevice(supabaseWrapper)
            try await mainUseQueue(supabaseWrapper)

        } catch let error as NSError where error.code == 1666 {
            try? await Task.sleep(nanoseconds: 1000000000)
        } catch {
            supabaseWrapper.log(level: .error, message: String(reflecting: error))
            try? await Task.sleep(nanoseconds: 5000000000)
        }
    }
}

RunLoop.main.run()
