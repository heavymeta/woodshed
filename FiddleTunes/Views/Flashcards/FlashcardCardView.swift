// FiddleTunes/Views/Flashcards/FlashcardCardView.swift
import SwiftUI

struct FlashcardCardView: View {
    let tune: Tune
    @EnvironmentObject var audio: AudioService

    var body: some View {
        VStack(spacing: 0) {
            // Mnemonic image
            Group {
                if let data = tune.mnemonicImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color("AppSurfaceContainer")
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundStyle(Color("AppOnSurfaceVariant"))
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipped()

            // Text + controls
            VStack(spacing: 6) {
                Text(tune.title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Color("AppOnSurface"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text([tune.type, tune.key, tune.tuning].joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(Color("AppOnSurfaceVariant"))

                Button {
                    if audio.isPlaying {
                        audio.stop()
                    } else if let filename = tune.audioFileName {
                        try? audio.play(filename: filename, rate: 1.0)
                    }
                } label: {
                    Image(systemName: audio.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color("AppPrimary"))
                        .frame(width: 48, height: 48)
                        .background(Color("AppPrimaryContainer"))
                        .clipShape(Circle())
                }
                .disabled(tune.audioFileName == nil)
                .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color("AppSurfaceContainerHigh"))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}
