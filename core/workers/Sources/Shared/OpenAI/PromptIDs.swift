// PromptIDs: identifiers for stored OpenAI prompts.
import Foundation

public struct PromptIDs {

    // MARK: - Text Optimization

    public static var textOptimization: String {
        return try! env("PROMPT_TEXT_OPTIMIZATION_ID", as: String.self)
    }

    // MARK: - Full Analysis

    public static var fullAnalysis: String {
        return try! env("PROMPT_FULL_ANALYSIS_ID", as: String.self)
    }
}
