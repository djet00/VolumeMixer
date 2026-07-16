import Testing
import Foundation
@testable import VolumeMixerCore

@Suite struct SettingsStoreTests {
    private func freshDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func defaultsForUnknownApp() {
        let store = SettingsStore(defaults: freshDefaults())
        let s = store.settings(for: "com.example.unknown")
        #expect(s.volume == 1.0)
        #expect(s.muted == false)
    }

    @Test func savesAndReads() {
        let d = freshDefaults()
        let store = SettingsStore(defaults: d)
        store.set(AppAudioSettings(volume: 0.3, muted: true), for: "com.spotify.client")
        let s = store.settings(for: "com.spotify.client")
        #expect(abs(s.volume - 0.3) < 0.0001)
        #expect(s.muted == true)
    }

    @Test func survivesNewStoreInstance() {
        let d = freshDefaults()
        SettingsStore(defaults: d).set(AppAudioSettings(volume: 0.5, muted: false), for: "a.b.c")
        let s = SettingsStore(defaults: d).settings(for: "a.b.c")
        #expect(abs(s.volume - 0.5) < 0.0001)
    }

    @Test func independentApps() {
        let store = SettingsStore(defaults: freshDefaults())
        store.set(AppAudioSettings(volume: 0.1, muted: false), for: "app.one")
        #expect(store.settings(for: "app.two").volume == 1.0)
    }

    @Test func pinnedDefaultsEmpty() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.pinnedBundleIDs.isEmpty)
    }

    @Test func pinAppendsUpToSix() {
        let store = SettingsStore(defaults: freshDefaults())
        for i in 1...6 {
            #expect(store.pin(bundleID: "app.\(i)", name: "App \(i)") == true)
        }
        #expect(store.pin(bundleID: "app.7", name: "App 7") == false)
        #expect(store.pinnedBundleIDs == (1...6).map { "app.\($0)" })
    }

    @Test func pinIsIdempotent() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.pin(bundleID: "a", name: "A") == true)
        #expect(store.pin(bundleID: "a", name: "A2") == false)
        #expect(store.pinnedBundleIDs == ["a"])
    }

    @Test func unpinRemovesAndFreesSlotAndMetadata() {
        let store = SettingsStore(defaults: freshDefaults())
        for i in 1...6 { _ = store.pin(bundleID: "app.\(i)", name: "A\(i)") }
        store.unpin(bundleID: "app.3")
        #expect(store.pinMetadata(for: "app.3") == nil)
        #expect(store.pin(bundleID: "app.7", name: "Seven") == true)
    }

    @Test func movePinnedUpDownPersistsAcrossStoreInstances() {
        let d = freshDefaults()
        let store = SettingsStore(defaults: d)
        _ = store.pin(bundleID: "a", name: "A")
        _ = store.pin(bundleID: "b", name: "B")
        store.movePinned(bundleID: "b", direction: .up)
        #expect(store.pinnedBundleIDs == ["b", "a"])
        store.movePinned(bundleID: "b", direction: .down)
        #expect(SettingsStore(defaults: d).pinnedBundleIDs == ["a", "b"])
    }

    @Test func pinMetadataPersists() {
        let d = freshDefaults()
        _ = SettingsStore(defaults: d).pin(bundleID: "com.spotify.client", name: "Spotify")
        #expect(SettingsStore(defaults: d).pinMetadata(for: "com.spotify.client")?.name == "Spotify")
    }

    @Test func updatePinMetadataChangesNameAndIgnoresUnpinned() {
        let store = SettingsStore(defaults: freshDefaults())
        _ = store.pin(bundleID: "a", name: "Old")
        store.updatePinMetadata(bundleID: "a", name: "New")
        store.updatePinMetadata(bundleID: "zzz", name: "Nope")
        #expect(store.pinMetadata(for: "a")?.name == "New")
        #expect(store.pinMetadata(for: "zzz") == nil)
    }

    @Test func sanitizesDuplicatesTruncatesAndDropsOrphanMetadata() {
        let d = freshDefaults()
        let raw = ["a", "", "b", "a", "c", "d", "e", "f", "g"]
        d.set(try! JSONEncoder().encode(raw), forKey: "pinnedBundleIDs")
        let meta = [
            "a": PinMetadata(name: "A"),
            "g": PinMetadata(name: "G"),
            "zzz": PinMetadata(name: "Z"),
        ]
        d.set(try! JSONEncoder().encode(meta), forKey: "pinnedMetadata")
        let store = SettingsStore(defaults: d)
        #expect(store.pinnedBundleIDs == ["a", "b", "c", "d", "e", "f"])
        #expect(store.pinMetadata(for: "g") == nil)
        #expect(store.pinMetadata(for: "zzz") == nil)
        #expect(store.pinMetadata(for: "a")?.name == "A")
    }
}
