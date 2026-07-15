import Testing
@testable import VolumeMixerCore

private func app(_ pid: Int32, _ bundle: String = "b", oid: UInt32 = 0) -> AudioApp {
    AudioApp(id: pid, objectID: oid, bundleID: bundle, name: "n", icon: nil)
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

    // CoreAudio пересоздаёт объект процесса (тот же pid, новый objectID):
    // tap привязан к старому объекту и мёртв — контроллер надо пересоздать.
    @Test func objectIDChangeMeansRecreate() {
        let d = ProcessDiff.between(old: [app(1, oid: 107)], new: [app(1, oid: 118)])
        #expect(d.removed.map(\.objectID) == [107])
        #expect(d.added.map(\.objectID) == [118])
    }
}
