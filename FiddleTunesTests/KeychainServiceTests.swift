// FiddleTunesTests/KeychainServiceTests.swift
import XCTest
@testable import FiddleTunes

final class KeychainServiceTests: XCTestCase {
    let testKey = "test.openai.key.unittest"

    override func tearDown() {
        KeychainService.delete(key: testKey)
    }

    func test_save_and_read_roundtrip() {
        KeychainService.save(key: testKey, value: "sk-test-1234")
        let result = KeychainService.read(key: testKey)
        XCTAssertEqual(result, "sk-test-1234")
    }

    func test_read_returns_nil_when_not_set() {
        let result = KeychainService.read(key: testKey)
        XCTAssertNil(result)
    }

    func test_overwrite_replaces_value() {
        KeychainService.save(key: testKey, value: "first")
        KeychainService.save(key: testKey, value: "second")
        XCTAssertEqual(KeychainService.read(key: testKey), "second")
    }

    func test_delete_removes_value() {
        KeychainService.save(key: testKey, value: "to-delete")
        KeychainService.delete(key: testKey)
        XCTAssertNil(KeychainService.read(key: testKey))
    }
}
