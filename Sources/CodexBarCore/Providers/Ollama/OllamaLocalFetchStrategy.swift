import Foundation

struct OllamaLocalFetchStrategy: ProviderFetchStrategy {
    let id: String = "ollama.api"
    let kind: ProviderFetchKind = .localProbe

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        // Only allow in auto/api mode, but NOT if cookie-based web scraping is configured.
        guard context.sourceMode == .auto || context.sourceMode == .api else { return false }
        // If cookie source is set (manual or auto), prefer web scraping over local API.
        guard context.settings?.ollama?.cookieSource == .off else { return false }
        return true
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        let settings = context.settings?.ollama
        let baseURL = try OllamaLocalClient.resolveBaseURL(settings: settings, env: context.env)
        let client = OllamaLocalClient(baseURL: baseURL, timeout: min(max(context.webTimeout, 1), 10))

        async let tags = client.listTags()
        async let version = client.version()

        let (tagResponse, versionResponse) = try await (tags, version)
        let models = tagResponse.models
            .map(\.name)
            .sorted()

        // There is no real quota concept for local Ollama; surface basic state via identity fields.
        let hostLabel = baseURL.host ?? baseURL.absoluteString
        let plan = "Local \u{00B7} \(models.count) models \u{00B7} v\(versionResponse.version)"

        let usage = UsageSnapshot(
            primary: RateWindow(usedPercent: 0, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: Date(),
            identity: ProviderIdentitySnapshot(
                providerID: .ollama,
                accountEmail: nil,
                accountOrganization: hostLabel,
                loginMethod: plan))

        return self.makeResult(usage: usage, sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        // If local API fails, fall back to web cookie flow (if enabled).
        true
    }
}
