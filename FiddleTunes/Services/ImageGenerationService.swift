// FiddleTunes/Services/ImageGenerationService.swift
import Foundation

enum ImageGenerationService {
    static let keychainKey = "fal.api.key"
    private static let endpoint = URL(string: "https://fal.run/fal-ai/flux/dev")!

    enum ImageGenError: Error {
        case missingAPIKey
        case badResponse(Int)
        case noImageInResponse
        case downloadFailed
    }

    private static let stylePrefix = "STYLE: linocut print illustration, bold hand-carved woodblock aesthetic. Two-color palette only: deep cobalt navy blue ink on warm cream/parchment background. Thick bold outlines with white relief lines carved through solid shapes. Chunky simplified silhouettes, visible texture and grain from the printing block, slight ink irregularity. Folk art quality, naive and handmade feeling. NO photorealism, NO gradients, NO shading, NO additional colors, NO text, NO words, NO letters, NO numbers in image. SCENE: "

    /// Generates a mnemonic image and returns JPEG Data.
    static func generate(prompt: String) async throws -> Data {
        guard let apiKey = KeychainService.read(key: keychainKey) else {
            throw ImageGenError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "prompt": stylePrefix + prompt,
            "image_size": "portrait_4_3",
            "num_inference_steps": 28,
            "guidance_scale": 3.5,
            "num_images": 1,
            "enable_safety_checker": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ImageGenError.badResponse(code)
        }

        struct FalResponse: Decodable {
            struct Image: Decodable { let url: String }
            let images: [Image]
        }
        let parsed = try JSONDecoder().decode(FalResponse.self, from: data)
        guard let urlString = parsed.images.first?.url,
              let imageURL = URL(string: urlString) else {
            throw ImageGenError.noImageInResponse
        }

        let (imageData, _) = try await URLSession.shared.data(from: imageURL)
        return imageData
    }
}
