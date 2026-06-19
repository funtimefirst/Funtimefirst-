import Foundation

class ClaudeService {
    private let apiKey: String
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-4-8"
    private var conversationHistory: [[String: String]] = []

    init() {
        apiKey = Bundle.main.object(forInfoDictionaryKey: "ClaudeAPIKey") as? String ?? ""
    }

    func sendMessage(_ userMessage: String) async throws -> String {
        guard !apiKey.isEmpty, apiKey != "YOUR_CLAUDE_API_KEY_HERE" else {
            throw ClaudeError.missingAPIKey
        }

        conversationHistory.append(["role": "user", "content": userMessage])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": "You are a friendly, concise voice assistant. Keep your responses short and conversational — ideally under 3 sentences — because your reply will be spoken aloud.",
            "messages": conversationHistory
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        let assistantMessage = decoded.content.first?.text ?? ""

        conversationHistory.append(["role": "assistant", "content": assistantMessage])

        return assistantMessage
    }

    func clearHistory() {
        conversationHistory.removeAll()
    }
}

// MARK: - Models

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key is missing. Open Info.plist and replace YOUR_CLAUDE_API_KEY_HERE with your key from console.anthropic.com."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .apiError(let code, let body):
            return "API error \(code): \(body)"
        }
    }
}
