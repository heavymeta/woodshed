// FiddleTunes/Views/Flashcards/FlashcardCardView.swift
import SwiftUI

struct FlashcardCardView: View {
    let tune: Tune
    let index: Int
    @EnvironmentObject var audio: AudioService
    @State private var isGeneratingImage = false

    private var isThisTunePlaying: Bool {
        audio.isPlaying && audio.currentFilename == tune.audioFileName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: title left, play button right
            HStack(alignment: .center) {
                Text(tune.title)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("AppOnSurface"))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Button {
                    if isThisTunePlaying { audio.stop() }
                    else if let fn = tune.audioFileName { try? audio.play(filename: fn, rate: 1.0) }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color("AppPrimary"))
                            .frame(width: 46, height: 46)
                        Image(systemName: isThisTunePlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(x: isThisTunePlaying ? 0 : 1.5)
                    }
                }
                .disabled(tune.audioFileName == nil)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            // Image fills remaining card height
            Group {
                if let data = tune.mnemonicImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    Color("AppSurfaceContainerLow")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            if isGeneratingImage {
                                VStack(spacing: 10) {
                                    ProgressView().tint(Color("AppOnSurfaceVariant"))
                                    Text("Generating image…")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color("AppOnSurfaceVariant"))
                                }
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color("AppOnSurfaceVariant").opacity(0.3))
                            }
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        .onAppear { generateImageIfNeeded() }
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
                print("FlashcardCardView: got scene for '\(tune.title)': \(scene.prefix(80))…")
                tune.mnemonicPrompt = scene
                let data = try await ImageGenerationService.generate(prompt: scene)
                tune.mnemonicImageData = data
            } catch MnemonicPromptService.Error.missingAPIKey {
                print("FlashcardCardView: OpenAI key missing — re-enter in Settings")
            } catch MnemonicPromptService.Error.badResponse(let code) {
                print("FlashcardCardView: Claude error \(code) for '\(tune.title)'")
            } catch ImageGenerationService.ImageGenError.missingAPIKey {
                print("FlashcardCardView: fal.ai key missing — re-enter in Settings")
            } catch ImageGenerationService.ImageGenError.badResponse(let code) {
                print("FlashcardCardView: fal.ai error \(code) for '\(tune.title)'")
            } catch {
                print("FlashcardCardView: generation failed for '\(tune.title)': \(error)")
            }
            isGeneratingImage = false
        }
    }
}
