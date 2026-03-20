// FiddleTunes/Helpers/FlashcardWeighting.swift
import Foundation

enum FlashcardWeighting {
    /// Returns a weight in [0, 1). Higher = more unknown = should appear sooner.
    static func weight(knownCount: Int, unknownCount: Int) -> Double {
        let unknown = Double(unknownCount)
        let total = Double(knownCount + unknownCount)
        return unknown / (total + 1.0)
    }

    /// Sorts items by descending weight (highest unknown ratio first).
    static func sort(_ items: [(id: Int, known: Int, unknown: Int)]) -> [(id: Int, known: Int, unknown: Int)] {
        items.sorted { a, b in
            weight(knownCount: a.known, unknownCount: a.unknown) >
            weight(knownCount: b.known, unknownCount: b.unknown)
        }
    }
}
