// FiddleTunes/Services/AudioService.swift
import Foundation
import AVFoundation

@MainActor
final class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()

    @Published var isPlaying = false
    @Published var isRecording = false

    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?

    private override init() {
        super.init()
        setupSession()
    }

    // MARK: - AVAudioSession

    private func setupSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioService: session setup failed: \(error)")
        }
    }

    // MARK: - Waveform Sampling (static — testable without AVFoundation)

    /// Downsamples raw PCM floats to exactly `targetCount` normalized amplitude values in [0, 1].
    static func normalize(samples: [Float], targetCount: Int) -> [Float] {
        guard !samples.isEmpty, targetCount > 0 else {
            return Array(repeating: 0.0, count: targetCount)
        }
        let chunkSize = max(1, samples.count / targetCount)
        var result: [Float] = []
        result.reserveCapacity(targetCount)
        let absMax = samples.map(abs).max() ?? 1.0
        let scale = absMax > 0 ? absMax : 1.0

        for i in 0..<targetCount {
            let start = i * chunkSize
            let end = min(start + chunkSize, samples.count)
            if start >= samples.count {
                result.append(0.0)
            } else {
                let chunk = samples[start..<end]
                let rms = sqrt(chunk.map { $0 * $0 }.reduce(0, +) / Float(chunk.count))
                result.append(min(rms / scale, 1.0))
            }
        }
        return result
    }

    /// Reads an audio file and returns exactly 50 normalized amplitude values.
    func sampleWaveform(from url: URL) -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: url),
              let format = AVAudioFormat(standardFormatWithSampleRate: audioFile.fileFormat.sampleRate, channels: 1) else {
            return Array(repeating: 0.0, count: 50)
        }
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              (try? audioFile.read(into: buffer)) != nil,
              let channelData = buffer.floatChannelData?[0] else {
            return Array(repeating: 0.0, count: 50)
        }
        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        return AudioService.normalize(samples: samples, targetCount: 50)
    }
}
