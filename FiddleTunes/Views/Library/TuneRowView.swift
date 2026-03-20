// FiddleTunes/Views/Library/TuneRowView.swift
import SwiftUI

struct TuneRowView: View {
    let tune: Tune
    let index: Int
    @EnvironmentObject var audio: AudioService

    var body: some View {
        HStack(spacing: 16) {
            // Zero-padded serif italic number (001, 002, …)
            Text(String(format: "%03d", index + 1))
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color("AppOnSurfaceVariant"))
                .frame(width: 38, alignment: .trailing)

            // Title
            Text(tune.title)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(Color("AppOnSurface"))
                .lineLimit(1)

            Spacer()

            // Simple triangle play button — no circle background
            Button {
                if audio.isPlaying {
                    audio.stop()
                } else if let filename = tune.audioFileName {
                    try? audio.play(filename: filename, rate: 1.0)
                }
            } label: {
                Image(systemName: audio.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("AppOnSurface"))
            }
            .disabled(tune.audioFileName == nil)
            .opacity(tune.audioFileName == nil ? 0.3 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color("AppSurface"))
        // No divider — design system forbids lines; whitespace separates rows
    }
}
