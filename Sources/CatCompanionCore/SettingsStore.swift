import Foundation
import Combine

public final class SettingsStore: ObservableObject {
    @Published public var settings: AppSettings {
        didSet {
            guard !isLoading else { return }
            save(settings)
        }
    }

    private let defaults: UserDefaults
    private let storageKey = "CatCompanion.Settings"
    private var isLoading = false

    public init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        self.settings = AppSettings.defaults()
        self.isLoading = true
        self.settings = load() ?? AppSettings.defaults()
        self.isLoading = false
    }

    public func reset() {
        KeychainHelper.delete(forKey: "gatewayToken")
        settings = AppSettings.defaults()
    }

    private func load() -> AppSettings? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var loaded = try? decoder.decode(AppSettings.self, from: data) else { return nil }
        // Ensure token is loaded from Keychain (decoder handles migration)
        loaded.assistant.gatewayToken = KeychainHelper.load(forKey: "gatewayToken") ?? loaded.assistant.gatewayToken
        return loaded
    }

    private func save(_ settings: AppSettings) {
        // Persist token to Keychain separately
        let token = settings.assistant.gatewayToken
        if token.isEmpty {
            KeychainHelper.delete(forKey: "gatewayToken")
        } else {
            KeychainHelper.save(token, forKey: "gatewayToken")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
