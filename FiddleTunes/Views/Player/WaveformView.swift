// FiddleTunes/Views/Player/WaveformView.swift
import SwiftUI

struct WaveformView: View, Animatable {
    let flatSamples: [Float]
    let realSamples: [Float]
    /// 0 = flat placeholder, 1 = actual waveform. SwiftUI interpolates this each frame.
    var waveProgress: Double
    var playhead: Double? = nil          // nil = not playing; color split happens here
    var onScrub: ((Double) -> Void)? = nil

    private let targetBars = 22
    private let gap: CGFloat = 5

    // Encode playhead as -1 when nil so SwiftUI can interpolate both values
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(waveProgress, playhead ?? -1) }
        set {
            waveProgress = newValue.first
            let p = newValue.second
            playhead = p < 0 ? nil : p
        }
    }

    // Pre-downsampled bars for flat and real states, interpolated per-bar in the canvas.
    private var flatBars: [Float] {
        downsample(flatSamples, to: min(targetBars, flatSamples.count))
    }

    private var realBars: [Float] {
        downsample(realSamples, to: min(targetBars, realSamples.count))
    }

    private func downsample(_ input: [Float], to count: Int) -> [Float] {
        guard input.count > count else { return input }
        let stride = Double(input.count) / Double(count)
        return (0..<count).map { i in
            let start = Int(Double(i) * stride)
            let end   = min(Int(Double(i + 1) * stride), input.count)
            let slice = input[start..<end]
            return slice.reduce(0, +) / Float(slice.count)
        }
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let flat   = flatBars
                let real   = realBars
                let count  = max(1, flat.count)
                let barW   = max(1, (size.width - gap * CGFloat(count - 1)) / CGFloat(count))
                let muted  = Color("AppPrimary").opacity(0.22)
                // Wave-front width in bars — controls how many bars animate simultaneously.
                let spread = 5.0

                for i in 0..<count {
                    // Each bar gets its own local progress so the reveal sweeps left to right.
                    let advance  = waveProgress * Double(count + Int(spread)) - Double(i)
                    let localP   = Float(max(0, min(1, advance / spread)))
                    let sample   = flat[i] + localP * (real[i] - flat[i])

                    // Minimum height = barW so smallest bar is a circle (pill shape)
                    let h        = max(barW, CGFloat(sample) * size.height)
                    let x        = CGFloat(i) * (barW + gap)
                    let fraction = (x + barW / 2) / size.width

                    // Shade entirely via bar opacity: no overlay
                    // Played bars fade from ~0.45 at the start to 1.0 right at the playhead,
                    // creating a trailing shadow. Unplayed bars hold flat muted opacity.
                    let color: Color = {
                        guard let p = playhead else { return muted }
                        if fraction <= p {
                            let t       = p > 0 ? fraction / p : 1.0  // 0 = start, 1 = at playhead
                            let opacity = 0.42 + 0.58 * t
                            return Color("AppPrimary").opacity(opacity)
                        } else {
                            return muted
                        }
                    }()

                    let rect = CGRect(x: x, y: (size.height - h) / 2, width: barW, height: h)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: barW / 2), with: .color(color))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        onScrub?(max(0, min(1, v.location.x / geo.size.width)))
                    }
            )
        }
    }
}
