// FiddleTunes/Views/Player/WaveformView.swift
import SwiftUI

struct WaveformView: View {
    let samples: [Float]        // expects 50 values in [0, 1]
    var barColor: Color = Color("AppPrimary")

    var body: some View {
        GeometryReader { geo in
            let count = max(1, samples.count)
            let spacing: CGFloat = 2
            let totalSpacing = spacing * CGFloat(count - 1)
            let barWidth = max(1, (geo.size.width - totalSpacing) / CGFloat(count))

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    let sample = CGFloat(samples[i])
                    let barHeight = max(3, sample * geo.size.height)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}
