// FiddleTunes/Views/AddTune/RecordAudioView.swift
import SwiftUI

struct RecordAudioView: View {
    @EnvironmentObject var audio: AudioService
    var onRecordingComplete: (String, [Float]) -> Void   // (tempFilename, waveform)
    var onImportSelected: (URL) -> Void

    @State private var recordingState: RecordingState = .idle
    @State private var capturedWaveform: [Float] = []
    @State private var showImportPicker = false
    @State private var pulseScale: CGFloat = 1.0

    enum RecordingState { case idle, recording, recorded }

    var body: some View {
        VStack(spacing: 24) {
            Text("Add Tune")
                .font(.custom("NotoSerif-Bold", size: 24))
                .foregroundStyle(Color("AppOnSurface"))
                .padding(.top, 8)

            Spacer()

            switch recordingState {
            case .idle:
                idleView
            case .recording:
                recordingView
            case .recorded:
                recordedView
            }

            Spacer()

            if recordingState == .idle {
                orDivider
                importButton
            }
        }
        .padding(.horizontal, 24)
        .background(Color("AppSurface"))
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                onImportSelected(url)
            }
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 16) {
            Button {
                startRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color("AppPrimary"))
                        .frame(width: 100, height: 100)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }
            Text("Tap to Record")
                .font(.custom("Manrope", size: 16))
                .foregroundStyle(Color("AppOnSurfaceVariant"))
        }
    }

    // MARK: - Recording

    private var recordingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseScale)
                Circle()
                    .fill(Color.red)
                    .frame(width: 80, height: 80)
                Image(systemName: "stop.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .onTapGesture { stopRecording() }

            Text("Recording...")
                .font(.custom("Manrope", size: 16))
                .foregroundStyle(.red)

            // Animated placeholder waveform
            WaveformView(
                samples: Array(repeating: Float.random(in: 0.2...0.8), count: 50),
                barColor: Color.red.opacity(0.6)
            )
            .frame(height: 50)
        }
    }

    // MARK: - Recorded

    private var recordedView: some View {
        VStack(spacing: 20) {
            WaveformView(samples: capturedWaveform)
                .frame(height: 60)

            HStack(spacing: 16) {
                Button("Re-record") {
                    capturedWaveform = []
                    recordingState = .idle
                }
                .font(.custom("Manrope", size: 16))
                .foregroundStyle(Color("AppOnSurfaceVariant"))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color("AppSurfaceContainerHigh"))
                .clipShape(Capsule())

                Button("Use This") {
                    onRecordingComplete("temp_recording.m4a", capturedWaveform)
                }
                .font(.custom("Manrope", size: 16))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color("AppPrimary"))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Import

    private var orDivider: some View {
        HStack {
            Rectangle().fill(Color("AppOutlineVariant")).frame(height: 1)
            Text("or")
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(Color("AppOnSurfaceVariant"))
                .padding(.horizontal, 8)
            Rectangle().fill(Color("AppOutlineVariant")).frame(height: 1)
        }
    }

    private var importButton: some View {
        Button {
            showImportPicker = true
        } label: {
            Label("Import Audio File", systemImage: "square.and.arrow.down")
                .font(.custom("Manrope", size: 16))
                .foregroundStyle(Color("AppPrimary"))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color("AppPrimaryContainer"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    private func startRecording() {
        do {
            try audio.startRecording()
            recordingState = .recording
            pulseScale = 1.3
        } catch {
            print("RecordAudioView: startRecording failed: \(error)")
        }
    }

    private func stopRecording() {
        let waveform = audio.stopRecording()
        capturedWaveform = waveform
        recordingState = .recorded
        pulseScale = 1.0
    }
}
