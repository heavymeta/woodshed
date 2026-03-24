// FiddleTunes/Views/Player/TunePlayerView.swift
import SwiftUI

struct TunePlayerView: View {
    let tune: Tune
    @EnvironmentObject var audio: AudioService
    @Environment(\.dismiss) private var dismiss

    @State private var playbackRate: Float = 1.0
    @State private var isGeneratingImage = false
    @State private var playbackError: String? = nil
    @State private var waveProgress: Double = 0

    private static let flatSamples = Array(repeating: Float(0.08), count: 50)

    private var realSamples: [Float] {
        tune.waveformSamples.isEmpty ? Self.flatSamples : tune.waveformSamples
    }

    private var isThisTunePlaying: Bool {
        audio.isPlaying && audio.currentFilename == tune.audioFileName
    }

    private let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Mnemonic image — portrait 3:4 card, centered
                mnemonicImageView
                    .frame(width: 240, height: 320)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)

                // Title
                Text(tune.title)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("AppOnSurface"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                // Tag chips
                HStack(spacing: 8) {
                    tagChip(tune.key)
                    Text("/")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("AppOnSurfaceVariant").opacity(0.6))
                    tagChip(tune.type)
                }
                .padding(.top, 10)

                // Waveform
                WaveformView(
                    flatSamples: Self.flatSamples,
                    realSamples: realSamples,
                    waveProgress: waveProgress,
                    playhead: isThisTunePlaying && audio.duration > 0
                        ? audio.currentTime / audio.duration
                        : nil,
                    onScrub: { audio.seek(toFraction: $0) }
                )
                .animation(.easeInOut(duration: 0.5), value: waveProgress)
                .animation(.easeInOut(duration: 0.35), value: isThisTunePlaying)
                .animation(.linear(duration: 0.08), value: audio.currentTime)
                .frame(height: 110)
                .padding(.horizontal, 24)
                .padding(.top, 36)

                // Playback controls
                HStack(spacing: 48) {
                    Button { audio.seek(by: -10) } label: {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 26))
                            .foregroundStyle(Color("AppOnSurface").opacity(0.6))
                    }
                    .disabled(!isThisTunePlaying)

                    // Play / pause circle
                    Button {
                        if isThisTunePlaying {
                            audio.stop()
                        } else if let filename = tune.audioFileName {
                            do {
                                try audio.play(filename: filename, rate: playbackRate)
                            } catch {
                                playbackError = "Could not play audio: \(error.localizedDescription)"
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color("AppPrimary"))
                                .frame(width: 72, height: 72)
                                .shadow(color: Color("AppPrimary").opacity(0.3), radius: 12, y: 6)
                            Image(systemName: isThisTunePlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(.white)
                                .offset(x: isThisTunePlaying ? 0 : 2)
                        }
                    }
                    .disabled(tune.audioFileName == nil)

                    Button { audio.seek(by: 10) } label: {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 26))
                            .foregroundStyle(Color("AppOnSurface").opacity(0.6))
                    }
                    .disabled(!isThisTunePlaying)
                }
                .padding(.top, 32)

                // Speed control
                VStack(spacing: 14) {
                    Text("TEMPO MODULATION")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(Color("AppOnSurfaceVariant"))

                    HStack(spacing: 0) {
                        ForEach(speedOptions, id: \.self) { rate in
                            Button {
                                playbackRate = rate
                                if isThisTunePlaying { audio.setRate(rate) }
                            } label: {
                                Text(speedLabel(rate))
                                    .font(.system(size: 14, weight: rate == playbackRate ? .semibold : .regular))
                                    .foregroundStyle(rate == playbackRate ? .white : Color("AppOnSurface"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background {
                                        if rate == playbackRate {
                                            RoundedRectangle(cornerRadius: 9)
                                                .fill(Color("AppPrimary"))
                                        }
                                    }
                            }
                        }
                    }
                    .padding(4)
                    .background(Color("AppSurfaceContainerHigh"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                .padding(.top, 36)
                .padding(.bottom, 48)
            }
        }
        .background(Color("AppSurface"))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            computeWaveformIfNeeded()
            generateImageIfNeeded()
        }
        .onDisappear { if isThisTunePlaying { audio.stop() } }
        .onChange(of: isThisTunePlaying) { _, playing in
            waveProgress = playing ? 1 : 0
        }
        .alert("Playback Error", isPresented: Binding(
            get: { playbackError != nil },
            set: { if !$0 { playbackError = nil } }
        )) {
            Button("OK") { playbackError = nil }
        } message: {
            Text(playbackError ?? "")
        }
    }

    @ViewBuilder
    private var mnemonicImageView: some View {
        let clip = RoundedRectangle(cornerRadius: 16)
        ZStack {
            if let data = tune.mnemonicImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .grayscale(1.0)
                    .overlay(Color("AppSecondary").opacity(0.15).blendMode(.multiply))
                    .clipShape(clip)
            } else {
                clip
                    .fill(Color("AppSurfaceContainerHigh"))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundStyle(Color("AppOnSurfaceVariant").opacity(0.4))
                    }
            }

            if isGeneratingImage {
                clip
                    .fill(.black.opacity(0.35))
                    .overlay { ProgressView().tint(.white) }
            }
        }
        .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
    }

    private func tagChip(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(0.8)
            .foregroundStyle(Color("AppOnSurfaceVariant"))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color("AppSurfaceContainerHigh"))
            .clipShape(Capsule())
    }

    private func speedLabel(_ rate: Float) -> String {
        switch rate {
        case 0.5:  return "0.5x"
        case 0.75: return "0.75x"
        case 1.0:  return "1.0x"
        case 1.25: return "1.25x"
        default:   return "\(rate)x"
        }
    }

    private func computeWaveformIfNeeded() {
        guard tune.waveformSamples.isEmpty, let filename = tune.audioFileName else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        Task.detached(priority: .userInitiated) {
            let samples = AudioService.shared.sampleWaveform(from: url)
            await MainActor.run { tune.waveformSamples = samples }
        }
    }

    private func generateImageIfNeeded() {
        guard tune.mnemonicImageData == nil, !isGeneratingImage else { return }
        isGeneratingImage = true
        Task {
            do {
                let scene = try await MnemonicPromptService.generate(
                    tuneName: tune.title,
                    genre: tune.type,
                    key: tune.key
                )
                tune.mnemonicPrompt = scene
                let data = try await ImageGenerationService.generate(prompt: scene)
                tune.mnemonicImageData = data
            } catch {
                print("TunePlayerView: image generation failed for '\(tune.title)': \(error)")
            }
            isGeneratingImage = false
        }
    }
}
