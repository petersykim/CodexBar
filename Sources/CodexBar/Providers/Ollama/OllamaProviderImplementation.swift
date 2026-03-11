import AppKit
import CodexBarCore
import CodexBarMacroSupport
import Foundation
import SwiftUI

@ProviderImplementationRegistration
struct OllamaProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .ollama

    @MainActor
    func observeSettings(_ settings: SettingsStore) {
        _ = settings.ollamaBaseURL
        _ = settings.ollamaCookieSource
        _ = settings.ollamaCookieHeader
    }

    @MainActor
    func settingsSnapshot(context: ProviderSettingsSnapshotContext) -> ProviderSettingsSnapshotContribution? {
        .ollama(context.settings.ollamaSettingsSnapshot(tokenOverride: context.tokenOverride))
    }

    @MainActor
    func tokenAccountsVisibility(context: ProviderSettingsContext, support: TokenAccountSupport) -> Bool {
        guard support.requiresManualCookieSource else { return true }
        if !context.settings.tokenAccounts(for: context.provider).isEmpty { return true }
        return context.settings.ollamaCookieSource == .manual
    }

    @MainActor
    func applyTokenAccountCookieSource(settings: SettingsStore) {
        if settings.ollamaCookieSource != .manual {
            settings.ollamaCookieSource = .manual
        }
    }

    @MainActor
    func settingsPickers(context: ProviderSettingsContext) -> [ProviderSettingsPickerDescriptor] {
        let cookieBinding = Binding(
            get: { context.settings.ollamaCookieSource.rawValue },
            set: { raw in
                context.settings.ollamaCookieSource = ProviderCookieSource(rawValue: raw) ?? .auto
            })
        let cookieOptions = ProviderCookieSourceUI.options(
            allowsOff: true,
            keychainDisabled: context.settings.debugDisableKeychainAccess)

        let cookieSubtitle: () -> String? = {
            ProviderCookieSourceUI.subtitle(
                source: context.settings.ollamaCookieSource,
                keychainDisabled: context.settings.debugDisableKeychainAccess,
                auto: "Automatic imports browser cookies.",
                manual: "Paste a Cookie header or cURL capture from Ollama settings.",
                off: "Ollama cookies are disabled.")
        }

        return [
            ProviderSettingsPickerDescriptor(
                id: "ollama-cookie-source",
                title: "Cookie source (optional)",
                subtitle: "Only needed for Ollama.com web usage (if supported).",
                dynamicSubtitle: cookieSubtitle,
                binding: cookieBinding,
                options: cookieOptions,
                isVisible: nil,
                onChange: nil),
        ]
    }

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "ollama-base-url",
                title: "Host",
                subtitle: "Ollama HTTP API base URL (default: http://127.0.0.1:11434)",
                kind: .plain,
                placeholder: "http://127.0.0.1:11434",
                binding: context.stringBinding(\.ollamaBaseURL),
                actions: [],
                isVisible: nil,
                onActivate: nil),
            ProviderSettingsFieldDescriptor(
                id: "ollama-cookie",
                title: "",
                subtitle: "",
                kind: .secure,
                placeholder: "Cookie: …",
                binding: context.stringBinding(\.ollamaCookieHeader),
                actions: [
                    ProviderSettingsActionDescriptor(
                        id: "ollama-open-settings",
                        title: "Open Ollama Settings",
                        style: .link,
                        isVisible: nil,
                        perform: {
                            if let url = URL(string: "https://ollama.com/settings") {
                                NSWorkspace.shared.open(url)
                            }
                        }),
                ],
                isVisible: { context.settings.ollamaCookieSource == .manual },
                onActivate: { context.settings.ensureOllamaCookieLoaded() }),
        ]
    }
}
