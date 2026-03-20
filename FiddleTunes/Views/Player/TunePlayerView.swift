// FiddleTunes/Views/Player/TunePlayerView.swift
import SwiftUI

struct TunePlayerView: View {
    let tune: Tune
    @EnvironmentObject var audio: AudioService
    @Environment(\.dismiss) private var dismiss

    @State private var playbackRate: Float = 1.0
    @State private var isGeneratingImage = false

    private let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tune.title)
                        .font(.custom("NotoSerif-Bold", size: 22))
                        .foregroundStyle(Color("AppOnSurface"))
                    Text([tune.type, tune.key, tune.tuning].joined(separator: " · "))
                        .font(.custom("Manrope", size: 13))
                        .foregroundStyle(Color("AppOnSurfaceVariant"))
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color("AppOnSurfaceVariant"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 20) {
                    // Mnemonic image
                    mnemonicImageView

                    // Waveform
                    WaveformView(samples: tune.waveformSamples.isEmpty
                                 ? Array(repeating: 0.3, count: 50)
                                 : tune.waveformSamples)
                        .frame(height: 60)
                        .padding(.horizontal, 20)

                    // Speed picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Speed")
                            .font(.custom("Manrope", size: 12))
                            .foregroundStyle(Color("AppOnSurfaceVariant"))
                            .padding(.horizontal, 20)

                        Picker("Speed", selection: $playbackRate) {
                            ForEach(speedOptions, id: \.self) { rate in
                                Text(speedLabel(rate)).tag(rate)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                        .onChange(of: playbackRate) { _, newRate in
                            if audio.isPlaying { audio.setRate(newRate) }
                        }
                    }

                    // Playback controls
                    HStack(spacing: 40) {
                        Button { audio.seek(by: -10) } label: {
                            Image(systemName: "backward.10")
                                .font(.system(size: 28))
                                .foregroundStyle(Color("AppPrimary"))
                        }

                        Button {
                            if audio.isPlaying {
                                audio.stop()
                            } else if let filename = tune.audioFileName {
                                try? audio.play(filename: filename, rate: playbackRate)
                            }
                        } label: {
                            Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(Color("AppPrimary"))
                        }
                        .disabled(tune.audioFileName == nil)

                        Button { audio.seek(by: 10) } label: {
                            Image(systemName: "forward.10")
                                .font(.system(size: 28))
                                .foregroundStyle(Color("AppPrimary"))
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color("AppSurface"))
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var mnemonicImageView: some View {
        ZStack {
            if let data = tune.mnemonicImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("AppSurfaceContainerHigh"))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundStyle(Color("AppOnSurfaceVariant"))
                    }
            }

            if isGeneratingImage {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.4))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
        .padding(.horizontal, 20)
        .onTapGesture { regenerateImage() }
    }

    private func speedLabel(_ rate: Float) -> String {
        switch rate {
        case 0.5:  return "0.5×"
        case 0.75: return "0.75×"
        case 1.0:  return "1×"
        case 1.25: return "1.25×"
        default:   return "\(rate)×"
        }
    }

    private func regenerateImage() {
        guard !isGeneratingImage else { return }
        isGeneratingImage = true
        Task {
            defer { isGeneratingImage = false }
            if let data = try? await ImageGenerationService.generate(prompt: tune.mnemonicPrompt) {
                await MainActor.run { tune.mnemonicImageData = data }
            }
        }
    }
}
