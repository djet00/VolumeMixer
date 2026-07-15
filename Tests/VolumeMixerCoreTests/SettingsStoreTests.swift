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
}
