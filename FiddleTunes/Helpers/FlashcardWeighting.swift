// FiddleTunes/Helpers/FlashcardWeighting.swift
import Foundation

enum FlashcardWeighting {
    /// Returns a weight in [0, 1). Higher = more unknown = should appear sooner.
    static func weight(knownCount: Int, unknownCount: Int) -> Double {
        let unknown = Double(unknownCount)
        let total = Double(knownCount + unknownCount)
        return unknown / (total + 1.0)
    }
}
