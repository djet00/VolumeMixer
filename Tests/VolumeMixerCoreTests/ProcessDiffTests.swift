import Testing
@testable import VolumeMixerCore

private func app(_ pid: Int32, _ bundle: String = "b") -> AudioApp {
    AudioApp(id: pid, objectID: 0, bundleID: bundle, name: "n", icon: nil)
}

@Suite struct ProcessDiffTests {
    @Test func detectsAdded() {
        let d = ProcessDiff.between(old: [app(1)], new: [app(1), app(2)])
        #expect(d.added.map(\.id) == [2])
        #expect(d.removed.isEmpty)
    }
    @Test func detectsRemoved() {
        let d = ProcessDiff.between(old: [app(1), app(2)], new: [app(2)])
        #expect(d.removed.map(\.id) == [1])
        #expect(d.added.isEmpty)
    }
    @Test func emptyToEmpty() {
        let d = ProcessDiff.between(old: [], new: [])
        #expect(d.added.isEmpty && d.removed.isEmpty)
    }
    @Test func sameListNoChanges() {
        let d = ProcessDiff.between(old: [app(1)], new: [app(1)])
        #expect(d.added.isEmpty && d.removed.isEmpty)
    }
}
