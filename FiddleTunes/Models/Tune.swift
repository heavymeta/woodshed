// FiddleTunes/Models/Tune.swift
import SwiftData
import Foundation

@Model
final class Tune {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var genre: String       // "Old Time" | "Scandi" | "Celtic"
    var type: String        // "Reel" | "Jig" | "Waltz" | "Breakdown" | "Hornpipe" | "Other"
    var key: String         // e.g. "D Major", "G Major", "A minor"
    var tuning: String      // "Standard" | "Cross-G" | "AEAE" | "Other"
    var audioFileName: String?
    @Attribute(.externalStorage) var mnemonicImageData: Data?
    var mnemonicPrompt: String
    var waveformSamples: [Float] = []
    var knownCount: Int = 0
    var unknownCount: Int = 0
    var dateAdded: Date = Date()

    init(title: String, genre: String, type: String, key: String, tuning: String, mnemonicPrompt: String) {
        self.title = title
        self.genre = genre
        self.type = type
        self.key = key
        self.tuning = tuning
        self.mnemonicPrompt = mnemonicPrompt
    }
}
