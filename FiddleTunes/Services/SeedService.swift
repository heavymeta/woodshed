// FiddleTunes/Services/SeedService.swift
import Foundation
import SwiftData

enum SeedService {
    private struct SeedTune: Decodable {
        let title: String
        let genre: String
        let type: String
        let key: String
        let tuning: String
        let mnemonicPrompt: String
        let audioFileName: String?
    }

    /// Patches tunes that are missing audioFileName (e.g. synced back from iCloud before the field existed).
    static func repairAudioFileNames(context: ModelContext) {
        guard let url   = Bundle.main.url(forResource: "seed_tunes", withExtension: "json"),
              let data  = try? Data(contentsOf: url),
              let seeds = try? JSONDecoder().decode([SeedTune].self, from: data)
        else { return }

        let tunes = (try? context.fetch(FetchDescriptor<Tune>())) ?? []
        let seedMap = Dictionary(uniqueKeysWithValues: seeds.compactMap { s -> (String, String)? in
            guard let fn = s.audioFileName else { return nil }
            return (s.title, fn)
        })

        var count = 0
        for tune in tunes where tune.audioFileName == nil {
            if let fn = seedMap[tune.title] {
                tune.audioFileName = fn
                count += 1
            }
        }
        if count > 0 {
            try? context.save()
            print("SeedService: repaired audioFileName for \(count) tunes")
        }
    }

    /// Clears all mnemonic image data and prompts so they regenerate with the latest pipeline.
    static func clearAllMnemonicImages(context: ModelContext) {
        let tunes = (try? context.fetch(FetchDescriptor<Tune>())) ?? []
        for tune in tunes {
            tune.mnemonicImageData = nil
            tune.mnemonicPrompt = ""
        }
        try? context.save()
        print("SeedService: cleared mnemonic images for \(tunes.count) tunes")
    }

    /// Inserts seed tunes from seed_tunes.json if the library is empty.
    /// Audio files are fetched separately by CloudKitSeedService.
    static func seedIfNeeded(context: ModelContext) {
        // UserDefaults flag prevents re-seeding when CloudKit causes the local store
        // to appear empty on subsequent launches before synced records arrive.
        let flagKey = "FiddleTunes.seedCompleted"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        let existing = (try? context.fetch(FetchDescriptor<Tune>())) ?? []
        if !existing.isEmpty {
            UserDefaults.standard.set(true, forKey: flagKey)
            return
        }

        guard let url   = Bundle.main.url(forResource: "seed_tunes", withExtension: "json"),
              let data  = try? Data(contentsOf: url),
              let seeds = try? JSONDecoder().decode([SeedTune].self, from: data)
        else { return }

        for seed in seeds {
            let tune = Tune(
                title: seed.title,
                genre: seed.genre,
                type: seed.type,
                key: seed.key,
                tuning: seed.tuning,
                mnemonicPrompt: seed.mnemonicPrompt
            )
            tune.audioFileName = seed.audioFileName   // set even before file exists on disk
            context.insert(tune)
        }
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    /// Removes duplicate tunes (same title). Keeps the record with the most data
    /// (prefers one with audioFileName, then mnemonicImageData, then earliest dateAdded).
    static func deduplicateTunes(context: ModelContext) {
        let tunes = (try? context.fetch(FetchDescriptor<Tune>(
            sortBy: [SortDescriptor(\.dateAdded, order: .forward)]
        ))) ?? []

        // Group by normalized title
        var groups: [String: [Tune]] = [:]
        for tune in tunes {
            let key = tune.title.trimmingCharacters(in: .whitespaces).lowercased()
            groups[key, default: []].append(tune)
        }

        var deletedCount = 0
        for (_, group) in groups where group.count > 1 {
            // Pick the keeper: most complete data wins
            let keeper = group.max { a, b in
                let scoreA = (a.audioFileName != nil ? 2 : 0) + (a.mnemonicImageData != nil ? 1 : 0)
                let scoreB = (b.audioFileName != nil ? 2 : 0) + (b.mnemonicImageData != nil ? 1 : 0)
                return scoreA < scoreB
            }!
            for tune in group where tune.id != keeper.id {
                context.delete(tune)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            try? context.save()
            print("SeedService: removed \(deletedCount) duplicate tunes")
        }
    }
}
