import Testing
@testable import VolumeMixerCore

private func proc(_ pid: Int32, _ bundle: String, name: String = "n", oid: UInt32 = 0, playing: Bool = false) -> AudioProcess {
    AudioProcess(pid: pid, objectID: oid, bundleID: bundle, name: name, icon: nil, isPlaying: playing)
}

@Suite struct AppGroupingTests {
    @Test func groupsProcessesOfSameAppIntoOneRow() {
        let apps = AudioApp.grouped(from: [
            proc(1, "arc", name: "Arc", playing: true),
            proc(2, "arc", name: "Arc", playing: false),
            proc(3, "tg", name: "Telegram", playing: false),
        ])
        #expect(apps.count == 2)
        #expect(apps.first { $0.bundleID == "arc" }?.processes.count == 2)
    }

    @Test func appIsPlayingIfAnyProcessPlays() {
        let apps = AudioApp.grouped(from: [
            proc(1, "arc", playing: false),
            proc(2, "arc", playing: true),
        ])
        #expect(apps[0].isPlaying == true)
    }

    @Test func playingAppsComeFirstThenAlphabetical() {
        let apps = AudioApp.grouped(from: [
            proc(1, "b.silent", name: "Аура", playing: false),
            proc(2, "a.silent", name: "Яндекс", playing: false),
            proc(3, "z.loud", name: "Zoom", playing: true),
        ])
        #expect(apps.map(\.bundleID) == ["z.loud", "b.silent", "a.silent"])
    }

    @Test func emptyInput() {
        #expect(AudioApp.grouped(from: []).isEmpty)
    }
}
