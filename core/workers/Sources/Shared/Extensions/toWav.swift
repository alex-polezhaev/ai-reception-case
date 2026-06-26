// Data.toWav: wraps raw PCM data in a WAV container header.
import Foundation

extension Data {
    func toWav() -> Data {
        let sampleRate = AudioConfig.sampleRate
        let channels = AudioConfig.channels
        let bitsPerSample = AudioConfig.bytesPerSample * 8

        var wavData = Data()

        // RIFF Header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(Swift.withUnsafeBytes(of: UInt32(36 + self.count).littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)

        // Format chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(Swift.withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(Swift.withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavData.append(Swift.withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) })
        wavData.append(Swift.withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        wavData.append(Swift.withUnsafeBytes(of: UInt32(sampleRate * channels * AudioConfig.bytesPerSample).littleEndian) { Data($0) })
        wavData.append(Swift.withUnsafeBytes(of: UInt16(channels * AudioConfig.bytesPerSample).littleEndian) { Data($0) })
        wavData.append(Swift.withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Data($0) })

        // Data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(Swift.withUnsafeBytes(of: UInt32(self.count).littleEndian) { Data($0) })
        wavData.append(self)

        return wavData
    }
}