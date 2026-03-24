// FiddleTunes/Views/Library/TuneRowView.swift
import SwiftUI

struct TuneRowView: View {
    let tune: Tune
    let index: Int
    var onTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @EnvironmentObject var audio: AudioService

    @State private var swipeOffset: CGFloat = 0

    private let deleteWidth: CGFloat = 76
    private let snapThreshold: CGFloat = 44

    private var isThisTunePlaying: Bool {
        audio.isPlaying && audio.currentFilename == tune.audioFileName
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button — sits behind the sliding row
            Button {
                onDelete?()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: deleteWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
            }

            // Row content
            HStack(spacing: 16) {
                Text(String(format: "%03d", index + 1))
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color("AppOnSurfaceVariant"))
                    .frame(width: 38, alignment: .trailing)

                Text(tune.title)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("AppOnSurface"))
                    .lineLimit(1)

                Spacer()

                Button {
                    if isThisTunePlaying {
                        audio.stop()
                    } else if let filename = tune.audioFileName {
                        try? audio.play(filename: filename, rate: 1.0)
                    }
                } label: {
                    Image(systemName: isThisTunePlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppOnSurface"))
                }
                .disabled(tune.audioFileName == nil)
                .opacity(tune.audioFileName == nil ? 0.3 : 1.0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color("AppSurface"))
            .overlay(
                HorizontalPanView(offset: $swipeOffset,
                                  deleteWidth: deleteWidth,
                                  snapThreshold: snapThreshold)
            )
            .offset(x: swipeOffset)
            .contentShape(Rectangle())
            .onTapGesture {
                if swipeOffset < 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        swipeOffset = 0
                    }
                } else {
                    onTap?()
                }
            }
        }
        .clipped()
    }
}

// MARK: - HorizontalPanView

private struct HorizontalPanView: UIViewRepresentable {
    @Binding var offset: CGFloat
    let deleteWidth: CGFloat
    let snapThreshold: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handle(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: HorizontalPanView
        private var startOffset: CGFloat = 0

        init(_ parent: HorizontalPanView) { self.parent = parent }

        @objc func handle(_ pan: UIPanGestureRecognizer) {
            let tx = pan.translation(in: pan.view).x
            switch pan.state {
            case .began:
                startOffset = parent.offset
            case .changed:
                parent.offset = max(-parent.deleteWidth, min(0, startOffset + tx))
            case .ended, .cancelled:
                let target: CGFloat = parent.offset < -parent.snapThreshold ? -parent.deleteWidth : 0
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    parent.offset = target
                }
            default: break
            }
        }

        // Only start for clearly horizontal gestures — checked before touch ownership is taken
        func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
            guard let pan = gr as? UIPanGestureRecognizer else { return false }
            let vel = pan.velocity(in: pan.view)
            return abs(vel.x) > abs(vel.y)
        }

        // Allow scroll view's recognizer to also run
        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}
