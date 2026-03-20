// FiddleTunesTests/FlashcardWeightingTests.swift
import XCTest
@testable import FiddleTunes

final class FlashcardWeightingTests: XCTestCase {
    func test_tune_with_more_unknowns_has_higher_weight() {
        let highWeight = FlashcardWeighting.weight(knownCount: 0, unknownCount: 5)
        let lowWeight = FlashcardWeighting.weight(knownCount: 10, unknownCount: 1)
        XCTAssertGreaterThan(highWeight, lowWeight)
    }

    func test_brand_new_tune_has_zero_weight() {
        let weight = FlashcardWeighting.weight(knownCount: 0, unknownCount: 0)
        XCTAssertEqual(weight, 0.0, accuracy: 0.001)
    }

    func test_all_known_approaches_zero() {
        let weight = FlashcardWeighting.weight(knownCount: 100, unknownCount: 0)
        XCTAssertLessThan(weight, 0.01)
    }

    func test_formula_denominator_avoids_division_by_zero() {
        // With knownCount=0, unknownCount=0: unknown/(total+1) = 0/(0+1) = 0
        let weight = FlashcardWeighting.weight(knownCount: 0, unknownCount: 0)
        XCTAssertFalse(weight.isNaN)
        XCTAssertFalse(weight.isInfinite)
    }
}
