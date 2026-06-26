// VadConfig: voice-activity-detection tuning parameters.
import Foundation

public struct VadConfig {
    public let minSessionLength: Int
    public let activityWindow: Int
    public let activityThreshold: Double
    public let endSilenceDuration: Int
    public let maxInnerSilence: Int
    public let minSilenceToTrim: Int
    public let silenceBuffer: Int

    public init() throws {
        minSessionLength = try env("VAD_MIN_SESSION_LENGTH", as: Int.self)
        activityWindow = try env("VAD_ACTIVITY_WINDOW", as: Int.self)
        activityThreshold = try env("VAD_ACTIVITY_THRESHOLD", as: Double.self)
        endSilenceDuration = try env("VAD_END_SILENCE_DURATION", as: Int.self)
        maxInnerSilence = try env("VAD_MAX_INNER_SILENCE", as: Int.self)
        minSilenceToTrim = try env("VAD_MIN_SILENCE_TO_TRIM", as: Int.self)
        silenceBuffer = try env("VAD_SILENCE_BUFFER", as: Int.self)
    }
}
