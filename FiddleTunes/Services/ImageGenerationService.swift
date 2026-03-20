// FiddleTunes/Services/ImageGenerationService.swift
import Foundation

enum ImageGenerationService {
    static let endpoint = URL(string: "https://api.openai.com/v1/images/generations")!

    enum ImageGenError: Error {
        case missingAPIKey
        case badResponse
        case decodingFailed
    }

    static func buildRequest(apiKey: String, prompt: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024",
            "response_format": "b64_json"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func decodeImageData(from responseData: Data) throws -> Data {
        struct Response: Decodable {
            struct Item: Decodable { let b64_json: String }
            let data: [Item]
        }
        let response = try JSONDecoder().decode(Response.self, from: responseData)
        guard let b64 = response.data.first?.b64_json,
              let imageData = Data(base64Encoded: b64) else {
            throw ImageGenError.decodingFailed
        }
        return imageData
    }

    /// Generates a mnemonic image and returns PNG Data.
    static func generate(prompt: String) async throws -> Data {
        guard let apiKey = KeychainService.read(key: "openai.api.key") else {
            throw ImageGenError.missingAPIKey
        }
        let request = try buildRequest(apiKey: apiKey, prompt: prompt)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ImageGenError.badResponse
        }
        return try decodeImageData(from: data)
    }
}
