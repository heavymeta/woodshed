// FiddleTunes/FiddleTunesApp.swift
import SwiftUI
import SwiftData
import UIKit

@main
struct FiddleTunesApp: App {
    @State private var showAPIKeyAlert = false
    @State private var pendingAPIKey = ""
    @State private var showOpenAIKeyAlert = false
    @State private var pendingOpenAIKey = ""

    init() {
        applyAppearance()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Tune.self])
        // Try CloudKit-backed store first; fall back to local if container isn't provisioned yet.
        if let container = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.iancurry.fiddletunes")
            )]
        ) {
            return container
        }
        do {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AudioService.shared)
                .onAppear {
                    SeedService.deduplicateTunes(context: sharedModelContainer.mainContext)
                    SeedService.seedIfNeeded(context: sharedModelContainer.mainContext)
                    SeedService.repairAudioFileNames(context: sharedModelContainer.mainContext)
                    CloudKitSeedService.downloadMissingAudio(container: sharedModelContainer)
                    // Delay so the view is fully presented before showing alerts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        checkAPIKey()
                    }
                }
                .alert("OpenAI API Key", isPresented: $showOpenAIKeyAlert) {
                    TextField("sk-...", text: $pendingOpenAIKey)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    Button("Save") {
                        KeychainService.save(key: MnemonicPromptService.keychainKey, value: pendingOpenAIKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        pendingOpenAIKey = ""
                        if KeychainService.read(key: ImageGenerationService.keychainKey) == nil {
                            showAPIKeyAlert = true
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Paste your Claude API key to enable mnemonic scene generation.")
                }
                .alert("Fal.ai API Key", isPresented: $showAPIKeyAlert) {
                    TextField("fal_key_...", text: $pendingAPIKey)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    Button("Save") {
                        KeychainService.save(key: ImageGenerationService.keychainKey, value: pendingAPIKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        pendingAPIKey = ""
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Paste your fal.ai API key to enable mnemonic image generation.")
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func checkAPIKey() {
        // Remove stale keys from previous service migrations
        KeychainService.delete(key: "openai.api.key")
        KeychainService.delete(key: "anthropic.api.key")

        // Trim any stored keys that have whitespace (fix for copy-paste artifacts)
        if let key = KeychainService.read(key: MnemonicPromptService.keychainKey) {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != key { KeychainService.save(key: MnemonicPromptService.keychainKey, value: trimmed) }
        }
        if let key = KeychainService.read(key: ImageGenerationService.keychainKey) {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != key { KeychainService.save(key: ImageGenerationService.keychainKey, value: trimmed) }
        }
        // Show OpenAI alert first; it chains to fal.ai alert on save if needed
        if KeychainService.read(key: MnemonicPromptService.keychainKey) == nil {
            showOpenAIKeyAlert = true
        } else if KeychainService.read(key: ImageGenerationService.keychainKey) == nil {
            showAPIKeyAlert = true
        }
    }

    private func applyAppearance() {
        let surface = UIColor(named: "AppSurface") ?? UIColor(red: 1, green: 0.988, blue: 0.969, alpha: 1)
        let onSurface = UIColor(named: "AppOnSurface") ?? UIColor(red: 0.22, green: 0.22, blue: 0.19, alpha: 1)
        let primary = UIColor(named: "AppPrimary") ?? UIColor(red: 0.35, green: 0.38, blue: 0.31, alpha: 1)

        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = surface
        navAppearance.shadowColor = UIColor(named: "AppOutlineVariant")?.withAlphaComponent(0.5)
        navAppearance.titleTextAttributes = [
            .foregroundColor: onSurface,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: onSurface,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = primary

        // Tab bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = surface
        tabAppearance.stackedLayoutAppearance.selected.iconColor = primary
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: primary]
        tabAppearance.stackedLayoutAppearance.normal.iconColor = onSurface.withAlphaComponent(0.45)
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: onSurface.withAlphaComponent(0.45)]
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
