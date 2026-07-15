import Foundation

public struct AppAudioSettings: Codable, Equatable {
    public var volume: Float   // позиция ползунка 0…1
    public var muted: Bool

    public init(volume: Float = 1.0, muted: Bool = false) {
        self.volume = volume
        self.muted = muted
    }
}

public final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "appAudioSettings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func settings(for bundleID: String) -> AppAudioSettings {
        all()[bundleID] ?? AppAudioSettings()
    }

    public func set(_ settings: AppAudioSettings, for bundleID: String) {
        var d = all()
        d[bundleID] = settings
        if let data = try? JSONEncoder().encode(d) {
            defaults.set(data, forKey: key)
        }
    }

    private func all() -> [String: AppAudioSettings] {
        guard let data = defaults.data(forKey: key),
              let d = try? JSONDecoder().decode([String: AppAudioSettings].self, from: data)
        else { return [:] }
        return d
    }
}
