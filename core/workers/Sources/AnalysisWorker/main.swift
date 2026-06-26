// AnalysisWorker: consumes the analysis queue and runs VAD-session analysis for each message.
import Foundation
import Shared

let workerName = "analysis-worker"
let queueName = "analysis-queue"

func main(_ supabaseWrapper: SupabaseWrapper) async throws {
    let supabase = supabaseWrapper.client

    let task = try await supabase.pgmqGet(queue: queueName, as: AnalysisMessage.self)

    supabaseWrapper.log(level: .info, message: "Processing analysis for vad_session_id: \(task.message.vad_session_id)")

    let vadSession: VadSession = try await supabase
        .from("vad_sessions")
        .select()
        .eq("id", value: task.message.vad_session_id)
        .single()
        .execute()
        .value

    let vadTranscription: VadTranscription = try await supabase
        .from("vad_transcriptions")
        .select()
        .eq("vad_session_id", value: vadSession.id)
        .single()
        .execute()
        .value

    supabaseWrapper.log(level: .info, message: "Found transcription with \(vadTranscription.text.count) characters")

    let openai = try await OpenAIClient(supabase)

    // MARK: - Text Optimization

    supabaseWrapper.log(level: .info, message: "Starting text optimization")

    let optimizationResult = try await openai.executePrompt(
        promptId: PromptIDs.textOptimization,
        variables: TextOptimizationPromptVariables(
            transcript: vadTranscription.text,
            session_id: vadSession.id.requireID().toString(),
            device_id: vadSession.device_id
        ),
        as: TextOptimizationResult.self
    )

    if optimizationResult.hasError {
        supabaseWrapper.log(level: .info, message: "Text optimization detected unsuitable content, marking session as unsuitable")

        let _: [VadSession] = try await supabase
            .from("vad_sessions")
            .update(["is_unsuitable": true])
            .eq("id", value: vadSession.id ?? 0)
            .execute()
            .value

        try await supabase.pgmqAck(queue: queueName, msgId: task.msg_id)
        return
    }

    guard let optimizedText = optimizationResult.optimized_text else {
        throw OpenAIError.decodingError("Optimization successful but no optimized text received")
    }

    supabaseWrapper.log(level: .info, message: "Text optimization completed, optimized text length: \(optimizedText.count)")

    // MARK: - Full Analysis

    supabaseWrapper.log(level: .info, message: "Starting full analysis")

    let analysisResult = try await openai.executePrompt(
        promptId: PromptIDs.fullAnalysis,
        variables: FullAnalysisPromptVariables(
            optimized_text: optimizedText,
            session_id: vadSession.id.requireID().toString(),
            device_id: vadSession.device_id
        ),
        as: FullAnalysisResult.self
    )

    let analysis = try VadAnalysis(
        id: nil,
        vad_session_id: vadSession.id.requireID(),
        title: analysisResult.title,
        type: analysisResult.type,
        keywords: analysisResult.keywords,
        products: analysisResult.products,
        quality: analysisResult.quality,
        optimized_text: optimizedText
    )

    let _: [VadAnalysis] = try await supabase
        .from("vad_analysis")
        .upsert(analysis, onConflict: "vad_session_id")
        .execute()
        .value

    try await supabase.pgmqAck(queue: queueName, msgId: task.msg_id)

    supabaseWrapper.log(level: .info, message: "Successfully completed analysis for session \(vadSession.id?.description ?? "unknown")")
}

Task {
    loadEnv()
    cleanTempDirectory(ext: "wav")

    let supabaseWrapper = try SupabaseWrapper(source: workerName)

    while true {
        do {
            try await main(supabaseWrapper)

        } catch let error as NSError where error.code == 1666 {
            // No tasks in queue — waiting
            try? await Task.sleep(nanoseconds: 1000000000)
        } catch {
            supabaseWrapper.log(level: .error, message: String(reflecting: error))
            try? await Task.sleep(nanoseconds: 5000000000)
        }
    }
}

RunLoop.main.run()
