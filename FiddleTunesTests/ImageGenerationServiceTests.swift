// FiddleTunesTests/ImageGenerationServiceTests.swift
import XCTest
@testable import FiddleTunes

final class ImageGenerationServiceTests: XCTestCase {

    func test_buildRequest_includes_authorization_header() throws {
        let request = try ImageGenerationService.buildRequest(apiKey: "sk-abc", prompt: "test prompt")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-abc")
    }

    func test_buildRequest_sets_json_content_type() throws {
        let request = try ImageGenerationService.buildRequest(apiKey: "sk-abc", prompt: "test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func test_buildRequest_encodes_prompt_in_body() throws {
        let request = try ImageGenerationService.buildRequest(apiKey: "sk-abc", prompt: "my prompt")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["prompt"] as? String, "my prompt")
        XCTAssertEqual(json["model"] as? String, "dall-e-3")
        XCTAssertEqual(json["response_format"] as? String, "b64_json")
    }

    func test_decodeImageData_extracts_base64_png() throws {
        let samplePNG = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes
        let b64 = samplePNG.base64EncodedString()
        let responseJSON = """
        {"data":[{"b64_json":"\(b64)"}]}
        """.data(using: .utf8)!
        let result = try ImageGenerationService.decodeImageData(from: responseJSON)
        XCTAssertEqual(result, samplePNG)
    }
}
