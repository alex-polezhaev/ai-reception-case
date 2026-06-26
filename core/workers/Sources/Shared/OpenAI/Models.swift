// OpenAI API request/response model types.
import Foundation

// MARK: - Main Request Structure

public struct OpenAIRequest<T: Codable>: Codable {
    public let prompt: PromptData<T>
}

public struct PromptData<T: Codable>: Codable {
    public let id: String
    public let variables: T
}

// MARK: - Analysis Models

public struct TextOptimizationResult: Codable {
    public let optimized_text: String?
    public let error: String?

    public var isSuccessful: Bool {
        return optimized_text != nil && error == nil
    }

    public var hasError: Bool {
        return error != nil
    }
}

public struct FullAnalysisResult: Codable {
    public let title: String
    public let type: String
    public let keywords: [String]
    public let products: [String]?
    public let quality: Int?
    public let attention_reason: String?
    public let employee_behavior: String?
    public let customer_sentiment: String?
}

// MARK: - Variables

public struct TextOptimizationPromptVariables: Codable {
    public let transcript: String
    public let session_id: String
    public let device_id: String

    public init(transcript: String, session_id: String, device_id: String) {
        self.transcript = transcript
        self.session_id = session_id
        self.device_id = device_id
    }
}

public struct FullAnalysisPromptVariables: Codable {
    public let optimized_text: String
    public let session_id: String
    public let device_id: String

    public init(optimized_text: String, session_id: String, device_id: String) {
        self.optimized_text = optimized_text
        self.session_id = session_id
        self.device_id = device_id
    }
}

// MARK: - Response Structure

struct OpenAIResponse: Codable {
    struct ContentBlock: Codable {
        let type: String
        let text: String
    }

    struct OutputBlock: Codable {
        let type: String
        let content: [ContentBlock]
    }

    let output: [OutputBlock]
}
public struct WhisperVerboseResponse: Decodable {
    public struct Segment: Decodable {
        public let id: Int
        public let start: Double
        public let end: Double
        public let text: String

        public var roundedStart: Double {
            return Double(round(100 * start) / 100)
        }

        public var roundedEnd: Double {
            return Double(round(100 * end) / 100)
        }
    }

    public let text: String
    public let segments: [Segment]

    public var duration: Double {
        return segments.last?.end ?? 0.0
    }
}

// MARK: - Error Models

public enum OpenAIError: Error {
    case apiError(Int, String)
    case decodingError(String)
}
