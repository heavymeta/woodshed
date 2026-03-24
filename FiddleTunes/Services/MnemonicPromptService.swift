// FiddleTunes/Services/MnemonicPromptService.swift
import Foundation

enum MnemonicPromptService {
    static let keychainKey = "openai.api.key.v2"
    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    enum Error: Swift.Error {
        case missingAPIKey
        case badResponse(Int)
        case decodingFailed
    }

    /// Asks GPT-4o to invent a vivid, bizarre, highly memorable mnemonic scene for the tune.
    static func generate(tuneName: String, genre: String, key: String) async throws -> String {
        guard let apiKey = KeychainService.read(key: keychainKey) else {
            print("MnemonicPromptService: no key stored for '\(keychainKey)'")
            throw Error.missingAPIKey
        }
        print("MnemonicPromptService: key length=\(apiKey.count) prefix='\(apiKey.prefix(12))…' suffix='…\(apiKey.suffix(6))'")

        let systemPrompt = "You are an expert in mnemonic memory techniques and image generation prompts. You help musicians memorize traditional tune names by creating vivid, unforgettable image descriptions. The images will be rendered as flat vector illustration in a muted, desaturated earthy palette — so describe scenes in terms of bold graphic shapes, clear subjects, and strong silhouettes rather than photorealistic detail, lighting, or atmospheric effects like glowing skies. Memorable images break categories of expectation: they are funny, lewd, grotesque, violent, or surreal — viscerally attention-grabbing. Generic or pleasant images are useless. Research the tune name — if it has a known meaning, story, or origin, use that as the basis. The tunes come from Celtic (Irish/Scottish), Scandinavian (Swedish/Norwegian), or American old-time traditions. Respond with only the scene description, no explanation, 2–3 sentences max."

        let userPrompt = "Tune title: \"\(tuneName)\" (\(genre), key of \(key)). Write a memorable image generation prompt for this tune that a musician could use as a mnemonic. The image must viscerally evoke the tune name — bizarre, funny, lewd, grotesque, or shocking. If you know what this tune is about or where the name comes from, use that. 2–3 sentences max."

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 300,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? "(unreadable)"
            print("MnemonicPromptService: \(statusCode) error — \(body)")
            throw Error.badResponse(statusCode)
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let parsed = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = parsed.choices.first?.message.content else {
            throw Error.decodingFailed
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
