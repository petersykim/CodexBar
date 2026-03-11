import Foundation

/// Minimal Ollama HTTP API client.
///
/// Docs: https://github.com/ollama/ollama/blob/main/docs/api.md
public struct OllamaLocalClient: Sendable {
    public struct TagResponse: Codable, Sendable {
        public struct Model: Codable, Sendable {
            public let name: String
            public let model: String?
            public let modified_at: Date?
            public let size: Int64?
            public let digest: String?
            public let details: Details?

            public struct Details: Codable, Sendable {
                public let family: String?
                public let families: [String]?
                public let parameter_size: String?
                public let quantization_level: String?
            }
        }

        public let models: [Model]
    }

    public struct VersionResponse: Codable, Sendable {
        public let version: String
    }

    public struct ChatRequest: Codable, Sendable {
        public struct Message: Codable, Sendable {
            public let role: String
            public let content: String
        }

        public let model: String
        public let messages: [Message]
        public let stream: Bool?

        public init(model: String, messages: [Message], stream: Bool? = nil) {
            self.model = model
            self.messages = messages
            self.stream = stream
        }
    }

    public struct ChatResponse: Codable, Sendable {
        public struct Message: Codable, Sendable {
            public let role: String
            public let content: String
        }

        public let model: String?
        public let created_at: Date?
        public let message: Message?
        public let done: Bool?
        public let total_duration: Int64?
        public let load_duration: Int64?
        public let prompt_eval_count: Int?
        public let eval_count: Int?
    }

    public enum OllamaError: LocalizedError, Sendable {
        case invalidBaseURL(String)
        case invalidResponse
        case httpError(Int, String)

        public var errorDescription: String? {
            switch self {
            case let .invalidBaseURL(value):
                return "Invalid Ollama base URL: \(value)"
            case .invalidResponse:
                return "Invalid response from Ollama."
            case let .httpError(code, body):
                if body.isEmpty { return "Ollama HTTP error \(code)." }
                return "Ollama HTTP error \(code): \(body)"
            }
        }
    }

    public let baseURL: URL
    public let timeout: TimeInterval

    public init(baseURL: URL, timeout: TimeInterval = 3) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    public static func resolveBaseURL(settings: ProviderSettingsSnapshot.OllamaProviderSettings?, env: [String: String]) throws -> URL {
        // Priority: Settings → env OLLAMA_HOST → default localhost.
        let raw = (settings?.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? env["OLLAMA_HOST"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "http://127.0.0.1:11434"

        // Ollama env var can be host:port; normalize to URL.
        let normalized: String
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            normalized = raw
        } else {
            normalized = "http://\(raw)"
        }

        guard let url = URL(string: normalized) else {
            throw OllamaError.invalidBaseURL(raw)
        }
        return url
    }

    public func listTags() async throws -> TagResponse {
        let url = self.baseURL.appending(path: "api/tags")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = self.timeout
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OllamaError.invalidResponse }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw OllamaError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TagResponse.self, from: data)
    }

    public func version() async throws -> VersionResponse {
        let url = self.baseURL.appending(path: "api/version")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = self.timeout
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OllamaError.invalidResponse }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw OllamaError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(VersionResponse.self, from: data)
    }

    /// Non-streaming chat request (for future use).
    public func chat(request payload: ChatRequest) async throws -> ChatResponse {
        let url = self.baseURL.appending(path: "api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = self.timeout
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OllamaError.invalidResponse }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw OllamaError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ChatResponse.self, from: data)
    }
}
