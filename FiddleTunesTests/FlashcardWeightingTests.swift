// FiddleTunesTests/FlashcardWeightingTests.swift
import XCTest
@testable import FiddleTunes

final class FlashcardWeightingTests: XCTestCase {
    func test_brand_new_tune_has_zero_weight() {
        let weight = FlashcardWeighting.weight(knownCount: 0, unknownCount: 0)
        XCTAssertEqual(weight, 0.0, accuracy: 0.001)
    }

    func test_all_known_approaches_zero() {
        let weight = FlashcardWeighting.weight(knownCount: 100, unknownCount: 0)
        XCTAssertLessThan(weight, 0.01)
    }

    func test_formula_denominator_avoids_division_by_zero() {
        let weight = FlashcardWeighting.weight(knownCount: 0, unknownCount: 0)
        XCTAssertFalse(weight.isNaN)
        XCTAssertFalse(weight.isInfinite)
    }

    func test_tune_with_more_unknowns_sorts_first() {
        let tunes: [(id: Int, known: Int, unknown: Int)] = [
            (id: 1, known: 10, unknown: 1),  // well-known, should be last
            (id: 2, known: 0,  unknown: 5),  // struggling, should be first
            (id: 3, known: 3,  unknown: 3),  // middle
        ]
        let sorted = FlashcardWeighting.sort(tunes)
        XCTAssertEqual(sorted[0].id, 2)
        XCTAssertEqual(sorted[1].id, 3)
        XCTAssertEqual(sorted[2].id, 1)
    }

    func test_sorted_deck_puts_highest_weight_first() {
        let deck: [(id: Int, known: Int, unknown: Int)] = [
            (id: 1, known: 5, unknown: 0),
            (id: 2, known: 0, unknown: 8),
            (id: 3, known: 2, unknown: 2),
        ]
        let sorted = FlashcardWeighting.sort(deck)
        XCTAssertEqual(sorted.first?.id, 2)
        XCTAssertEqual(sorted.last?.id, 1)
    }
}
