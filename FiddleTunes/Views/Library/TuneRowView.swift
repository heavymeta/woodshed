// FiddleTunes/Views/Library/TuneRowView.swift
import SwiftUI

struct TuneRowView: View {
    let tune: Tune
    let index: Int
    @EnvironmentObject var audio: AudioService

    var body: some View {
        HStack(spacing: 12) {
            // Index number
            Text("\(index + 1)")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(Color("AppPrimary"))
                .frame(width: 32, alignment: .trailing)

            // Title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(tune.title)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(Color("AppOnSurface"))
                    .lineLimit(1)

                Text([tune.type, tune.key, tune.tuning].joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(Color("AppOnSurfaceVariant"))
                    .lineLimit(1)
            }

            Spacer()

            // Play/Stop button
            Button {
                if audio.isPlaying {
                    audio.stop()
                } else if let filename = tune.audioFileName {
                    try? audio.play(filename: filename, rate: 1.0)
                }
            } label: {
                Image(systemName: audio.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color("AppPrimary"))
                    .frame(width: 40, height: 40)
                    .background(Color("AppPrimaryContainer"))
                    .clipShape(Circle())
            }
            .disabled(tune.audioFileName == nil)
            .opacity(tune.audioFileName == nil ? 0.4 : 1.0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("AppSurface"))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color("AppOutlineVariant"))
                .frame(height: 0.5)
        }
    }
}
