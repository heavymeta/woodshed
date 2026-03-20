// FiddleTunes/Views/AddTune/TuneMetadataFormView.swift
import SwiftUI
import SwiftData

struct TuneMetadataFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var audio: AudioService

    // Audio data from step 1
    let audioSourceURL: URL?        // nil if recorded (use saveRecording)
    let tempFilename: String?       // non-nil if recorded
    let previewWaveform: [Float]

    @State private var title = ""
    @State private var genre = "Old Time"
    @State private var type = "Reel"
    @State private var key = "D Major"
    @State private var tuning = "Standard"
    @State private var mnemonicPrompt = ""
    @State private var isSaving = false

    private let genres  = ["Old Time", "Scandi", "Celtic"]
    private let types   = ["Reel", "Jig", "Waltz", "Breakdown", "Hornpipe", "Other"]
    private let keys    = ["D Major", "G Major", "A Major", "E Major", "A minor", "D minor", "G minor", "Other"]
    private let tunings = ["Standard", "Cross-G", "AEAE", "Other"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Tune Details")
                    .font(.custom("NotoSerif-Bold", size: 22))
                    .foregroundStyle(Color("AppOnSurface"))
                    .padding(.top, 8)

                formField("Title") {
                    TextField("e.g. Midnight on the Water", text: $title)
                        .font(.custom("Manrope", size: 16))
                }

                pickerField("Genre", selection: $genre, options: genres)
                pickerField("Type", selection: $type, options: types)
                pickerField("Key", selection: $key, options: keys)
                pickerField("Tuning", selection: $tuning, options: tunings)

                formField("Mnemonic Prompt") {
                    TextField("Describe an image to help you remember this tune...",
                              text: $mnemonicPrompt, axis: .vertical)
                        .font(.custom("Manrope", size: 15))
                        .lineLimit(3...6)
                }

                Button {
                    Task { await saveTune() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save Tune")
                                .font(.custom("Manrope", size: 17))
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(title.isEmpty ? Color("AppPrimary").opacity(0.4) : Color("AppPrimary"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(title.isEmpty || isSaving)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color("AppSurface"))
    }

    @ViewBuilder
    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.custom("Manrope", size: 12))
                .fontWeight(.semibold)
                .foregroundStyle(Color("AppOnSurfaceVariant"))
            content()
                .padding(12)
                .background(Color("AppSurfaceContainerHigh"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func pickerField(_ label: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.custom("Manrope", size: 12))
                .fontWeight(.semibold)
                .foregroundStyle(Color("AppOnSurfaceVariant"))
            Picker(label, selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("AppSurfaceContainerHigh"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func saveTune() async {
        isSaving = true
        defer { isSaving = false }

        // 1. Resolve audio file
        var filename: String? = nil
        var waveform: [Float] = previewWaveform

        do {
            if let sourceURL = audioSourceURL {
                // Imported file
                let result = try audio.importAudio(from: sourceURL)
                filename = result.filename
                waveform = result.waveform
            } else if let temp = tempFilename {
                // Recorded file — move from temp to Documents
                let savedName = UUID().uuidString + ".m4a"
                filename = try audio.saveRecording(named: savedName)
                _ = temp // temp filename was "temp_recording.m4a", now saved as savedName
            }
        } catch {
            print("AddTune: audio save failed: \(error)")
        }

        // 2. Create and insert Tune
        let tune = Tune(
            title: title,
            genre: genre,
            type: type,
            key: key,
            tuning: tuning,
            mnemonicPrompt: mnemonicPrompt
        )
        tune.audioFileName = filename
        tune.waveformSamples = waveform
        modelContext.insert(tune)

        // 3. Generate mnemonic image async (best effort)
        if !mnemonicPrompt.isEmpty {
            if let imageData = try? await ImageGenerationService.generate(prompt: mnemonicPrompt) {
                tune.mnemonicImageData = imageData
            }
        }

        dismiss()
    }
}
