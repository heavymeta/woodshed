// FiddleTunes/FiddleTunesApp.swift
import SwiftUI
import SwiftData

@main
struct FiddleTunesApp: App {
    @State private var showAPIKeyAlert = false
    @State private var pendingAPIKey = ""

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Tune.self])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.iancurry.fiddletunes")
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { checkAPIKey() }
                .alert("OpenAI API Key", isPresented: $showAPIKeyAlert) {
                    TextField("sk-...", text: $pendingAPIKey)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    Button("Save") {
                        KeychainService.save(key: "openai.api.key", value: pendingAPIKey)
                        pendingAPIKey = ""
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Paste your OpenAI API key to enable mnemonic image generation.")
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func checkAPIKey() {
        if KeychainService.read(key: "openai.api.key") == nil {
            showAPIKeyAlert = true
        }
    }
}
