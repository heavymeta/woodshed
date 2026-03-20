// FiddleTunes/Views/AddTune/AddTuneView.swift
import SwiftUI

struct AddTuneView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var audio: AudioService

    enum Step { case source, metadata }

    @State private var step: Step = .source
    @State private var audioSourceURL: URL? = nil
    @State private var tempFilename: String? = nil
    @State private var previewWaveform: [Float] = []

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .source:
                    RecordAudioView(
                        onRecordingComplete: { filename, waveform in
                            tempFilename = filename
                            previewWaveform = waveform
                            audioSourceURL = nil
                            step = .metadata
                        },
                        onImportSelected: { url in
                            audioSourceURL = url
                            tempFilename = nil
                            previewWaveform = []
                            step = .metadata
                        }
                    )
                case .metadata:
                    TuneMetadataFormView(
                        audioSourceURL: audioSourceURL,
                        tempFilename: tempFilename,
                        previewWaveform: previewWaveform
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step == .metadata {
                        Button("Back") { step = .source }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color("AppOnSurfaceVariant"))
                }
            }
        }
        .background(Color("AppSurface"))
    }
}
