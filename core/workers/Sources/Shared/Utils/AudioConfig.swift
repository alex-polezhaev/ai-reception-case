// AudioConfig: shared audio format constants (sample rate, channels).
import Foundation

public struct AudioConfig {
    public static let sampleRate: Int = 16000
    public static let channels: Int = 1
    public static let bitsPerSample: Int = 16
    public static let bytesPerSample: Int = 2
    public static let expectedDurationSeconds: Double = 60.0
    public static let bytesPerSecond: Int = sampleRate * channels * bytesPerSample
}
