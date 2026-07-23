import Foundation

public struct AppAudioSettings: Codable, Equatable {
    public var volume: Float   // позиция ползунка 0…1
    public var muted: Bool

    public init(volume: Float = 1.0, muted: Bool = false) {
        self.volume = volume
        self.muted = muted
    }
}

public struct PinMetadata: Codable, Equatable {
    public var name: String
    public init(name: String) { self.name = name }
}

public enum PinMoveDirection { case up, down }

public final class SettingsStore {
    public static let pinLimit = 6

    private let defaults: UserDefaults
    private let key = "appAudioSettings"
    private let pinnedBundleIDsKey = "pinnedBundleIDs"
    private let pinnedMetadataKey = "pinnedMetadata"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sanitizePinsIfNeeded()
    }

    public var pinnedBundleIDs: [String] {
        decode([String].self, key: pinnedBundleIDsKey) ?? []
    }

    public func canPin(bundleID: String) -> Bool {
        !bundleID.isEmpty
            && !pinnedBundleIDs.contains(bundleID)
            && pinnedBundleIDs.count < Self.pinLimit
    }

    @discardableResult
    public func pin(bundleID: String, name: String) -> Bool {
        guard canPin(bundleID: bundleID) else { return false }
        var ids = pinnedBundleIDs
        ids.append(bundleID)
        encode(ids, key: pinnedBundleIDsKey)
        var meta = metadata()
        meta[bundleID] = PinMetadata(name: name)
        encode(meta, key: pinnedMetadataKey)
        return true
    }

    public func unpin(bundleID: String) {
        var ids = pinnedBundleIDs
        ids.removeAll { $0 == bundleID }
        encode(ids, key: pinnedBundleIDsKey)
        var meta = metadata()
        meta.removeValue(forKey: bundleID)
        encode(meta, key: pinnedMetadataKey)
    }

    public func movePinned(bundleID: String, direction: PinMoveDirection) {
        var ids = pinnedBundleIDs
        guard let index = ids.firstIndex(of: bundleID) else { return }
        switch direction {
        case .up:
            guard index > 0 else { return }
            ids.swapAt(index, index - 1)
        case .down:
            guard index < ids.count - 1 else { return }
            ids.swapAt(index, index + 1)
        }
        encode(ids, key: pinnedBundleIDsKey)
    }

    public func pinMetadata(for bundleID: String) -> PinMetadata? {
        metadata()[bundleID]
    }

    public func updatePinMetadata(bundleID: String, name: String) {
        guard pinnedBundleIDs.contains(bundleID) else { return }
        var meta = metadata()
        meta[bundleID] = PinMetadata(name: name)
        encode(meta, key: pinnedMetadataKey)
    }

    public func settings(for bundleID: String) -> AppAudioSettings {
        all()[bundleID] ?? AppAudioSettings()
    }

    public func set(_ settings: AppAudioSettings, for bundleID: String) {
        var d = all()
        d[bundleID] = settings
        encode(d, key: key)
    }

    private func all() -> [String: AppAudioSettings] {
        decode([String: AppAudioSettings].self, key: key) ?? [:]
    }

    private func metadata() -> [String: PinMetadata] {
        decode([String: PinMetadata].self, key: pinnedMetadataKey) ?? [:]
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func sanitizePinsIfNeeded() {
        var seen = Set<String>()
        var sanitized: [String] = []
        for id in pinnedBundleIDs where !id.isEmpty && seen.insert(id).inserted {
            sanitized.append(id)
            if sanitized.count == Self.pinLimit { break }
        }
        if sanitized != pinnedBundleIDs {
            encode(sanitized, key: pinnedBundleIDsKey)
        }
        let keep = Set(sanitized)
        let meta = metadata().filter { keep.contains($0.key) }
        if meta != metadata() {
            encode(meta, key: pinnedMetadataKey)
        }
    }
}
