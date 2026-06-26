// TranscriptionWorker: consumes the transcription queue and transcribes session audio via Whisper.
import Foundation
import Shared
import Supabase

let workerName = "transcription-worker"
let queueName = "transcription-queue"

func main(_ supabaseWrapper: SupabaseWrapper) async throws {
    let supabase = supabaseWrapper.client

    let task = try await supabase.pgmqGet(queue: queueName, as: TranscriptionMessage.self)

    let vadSession: VadSession = try await supabase
        .from("vad_sessions")
        .select()
        .eq("id", value: task.message.vad_session_id)
        .single()
        .execute()
        .value

    let s3 = try S3Wrapper()
    let bucket = try env("S3_SESSIONS_WAV_BUCKET", as: String.self)
    let wavData = try await s3.download(bucket: bucket, key: vadSession.s3_key)

    let openai = try await OpenAIClient(supabase)

    let whisperResult = try await openai.transcribe(
        file: wavData,
        fileName: "session_\(vadSession.id ?? 0).wav"
    )

    let segments = whisperResult.segments.map { segment in
        TranscriptionSegment(
            start: segment.roundedStart,
            end: segment.roundedEnd,
            text: segment.text
        )
    }

    let newTranscription = try VadTranscription(
        id: nil,
        vad_session_id: vadSession.id.requireID(),
        text: whisperResult.text,
        segments: segments
    )

    let _: [VadTranscription] = try await supabase
        .from("vad_transcriptions")
        .upsert(newTranscription, onConflict: "vad_session_id")
        .select()
        .execute()
        .value

    try await supabase.pgmqAck(queue: queueName, msgId: task.msg_id)
}

Task {
    loadEnv()

    let supabaseWrapper = try SupabaseWrapper(source: workerName)

    cleanTempDirectory(ext: "wav")

    while true {
        do {
            try await main(supabaseWrapper)

        } catch let error as NSError where error.code == 1666 {
            try? await Task.sleep(nanoseconds: 1000000000)
        } catch {
            supabaseWrapper.log(level: .error, message: String(reflecting: error))
            try? await Task.sleep(nanoseconds: 5000000000)
        }
    }
}

RunLoop.main.run()
