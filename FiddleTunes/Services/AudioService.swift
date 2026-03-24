// FiddleTunes/Services/AudioService.swift
import Foundation
import AVFoundation

@MainActor
final class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()

    @Published var isPlaying = false
    @Published var isRecording = false
    @Published var currentFilename: String? = nil
    @Published var currentTime: TimeInterval = 0

    var duration: TimeInterval { player?.duration ?? 0 }

    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var playbackTimer: Timer?

    private override init() {
        super.init()
        setupSession()
    }

    // MARK: - AVAudioSession

    private func setupSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioService: session setup failed: \(error)")
        }
        #endif
    }

    // MARK: - Waveform Sampling (static — testable without AVFoundation)

    /// Downsamples raw PCM floats to exactly `targetCount` normalized amplitude values in [0, 1].
    nonisolated static func normalize(samples: [Float], targetCount: Int) -> [Float] {
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
        // Re-normalize so the loudest bar reaches 1.0 for better visual range
        let peak = result.max() ?? 1.0
        if peak > 0 { result = result.map { $0 / peak } }
        return result
    }

    /// Reads an audio file and returns exactly 50 normalized amplitude values.
    nonisolated func sampleWaveform(from url: URL) -> [Float] {
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

    // MARK: - Recording

    private var tempRecordingURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("temp_recording.m4a")
    }

    func startRecording() throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try AVAudioRecorder(url: tempRecordingURL, settings: settings)
        recorder?.delegate = self
        recorder?.record()
        isRecording = true
    }

    /// Stops recording and returns the waveform samples. Call `saveRecording(named:)` to persist.
    func stopRecording() -> [Float] {
        recorder?.stop()
        isRecording = false
        return sampleWaveform(from: tempRecordingURL)
    }

    /// Moves the temp recording to the Documents directory. Returns the filename.
    @discardableResult
    func saveRecording(named filename: String) throws -> String {
        let dest = documentsURL(for: filename)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempRecordingURL, to: dest)
        return filename
    }

    func cancelRecording() {
        recorder?.stop()
        recorder?.deleteRecording()
        isRecording = false
    }

    // MARK: - Playback

    func play(filename: String, rate: Float = 1.0) throws {
        // Stop recorder if active
        if isRecording { cancelRecording() }
        // Stop current player
        player?.stop()

        let url = documentsURL(for: filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        player = try AVAudioPlayer(contentsOf: url)
        player?.enableRate = true
        player?.prepareToPlay()
        player?.rate = rate
        player?.delegate = self
        player?.play()
        isPlaying = true
        currentFilename = filename
        startTimer()
    }

    func stop() {
        player?.stop()
        isPlaying = false
        currentFilename = nil
        stopTimer()
        currentTime = 0
    }

    func seek(by seconds: TimeInterval) {
        guard let player else { return }
        player.currentTime = max(0, min(player.duration, player.currentTime + seconds))
        currentTime = player.currentTime
    }

    func seek(toFraction fraction: Double) {
        guard let player else { return }
        player.currentTime = fraction * player.duration
        currentTime = player.currentTime
    }

    private func startTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTime = self?.player?.currentTime ?? 0
            }
        }
    }

    private func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    func setRate(_ rate: Float) {
        player?.rate = rate
    }

    // MARK: - Import

    func importAudio(from sourceURL: URL) throws -> (filename: String, waveform: [Float]) {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }
        let filename = UUID().uuidString + "." + sourceURL.pathExtension
        let dest = documentsURL(for: filename)
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        let waveform = sampleWaveform(from: dest)
        return (filename, waveform)
    }

    // MARK: - Delete

    func deleteAudioFile(named filename: String) {
        let url = documentsURL(for: filename)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Helpers

    private func documentsURL(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }
}

// MARK: - Delegates

extension AudioService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentFilename = nil
            self.stopTimer()
            self.currentTime = 0
        }
    }
}

extension AudioService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            // Error surfaced via isRecording state change; caller observes via @Published
        }
    }
}
