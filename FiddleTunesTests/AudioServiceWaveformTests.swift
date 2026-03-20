// FiddleTunesTests/AudioServiceWaveformTests.swift
import XCTest
@testable import FiddleTunes

final class AudioServiceWaveformTests: XCTestCase {

    func test_normalize_returns_exactly_50_values() {
        let samples = Array(repeating: Float(0.5), count: 1000)
        let result = AudioService.normalize(samples: samples, targetCount: 50)
        XCTAssertEqual(result.count, 50)
    }

    func test_normalize_values_in_zero_to_one_range() {
        let samples = (0..<500).map { Float($0) }
        let result = AudioService.normalize(samples: samples, targetCount: 50)
        XCTAssertTrue(result.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
    }

    func test_normalize_silent_audio_returns_zeros() {
        let samples = Array(repeating: Float(0.0), count: 200)
        let result = AudioService.normalize(samples: samples, targetCount: 50)
        XCTAssertTrue(result.allSatisfy { $0 == 0.0 })
    }

    func test_normalize_handles_fewer_samples_than_target() {
        let samples = Array(repeating: Float(0.3), count: 10)
        let result = AudioService.normalize(samples: samples, targetCount: 50)
        XCTAssertEqual(result.count, 50)
    }
}
