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
    }

    /// Inserts seed tunes from seed_tunes.json if the library is empty.
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Tune>())) ?? []
        guard existing.isEmpty else { return }

        guard let url = Bundle.main.url(forResource: "seed_tunes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
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
            context.insert(tune)
        }
    }
}
