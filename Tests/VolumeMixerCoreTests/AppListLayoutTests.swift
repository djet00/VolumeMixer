import Testing
@testable import VolumeMixerCore

private func app(_ id: String, name: String, playing: Bool, pid: Int32 = 1) -> AudioApp {
    AudioApp(
        bundleID: id,
        name: name,
        icon: nil,
        isPlaying: playing,
        processes: [
            AudioProcess(
                pid: pid,
                objectID: 0,
                bundleID: id,
                name: name,
                icon: nil,
                isPlaying: playing
            ),
        ]
    )
}

@Suite struct AppListLayoutTests {
    @Test func pinnedLiveStaysInPinnedEvenIfSilent() {
        let apps = [
            app("p", name: "Pin", playing: false, pid: 1),
            app("x", name: "Other", playing: true, pid: 2),
        ]
        let (sections, _) = AppListLayout.layout(
            apps: apps,
            pinnedIDs: ["p"],
            audibleLevels: ["x": 0.5],
            metadataName: { _ in nil },
            state: .init(),
            now: 0
        )
        #expect(sections.pinned.map(\.bundleID) == ["p"])
        #expect(sections.playing.map(\.bundleID) == ["x"])
        #expect(sections.silent.isEmpty)
    }

    @Test func pinnedPlayingDoesNotAppearInPlayingSection() {
        let apps = [
            app("p", name: "Pin", playing: true, pid: 1),
            app("x", name: "Other", playing: true, pid: 2),
        ]
        let (sections, _) = AppListLayout.layout(
            apps: apps,
            pinnedIDs: ["p"],
            audibleLevels: ["p": 1, "x": 0.2],
            metadataName: { _ in nil },
            state: .init(),
            now: 0
        )
        #expect(sections.pinned.map(\.bundleID) == ["p"])
        #expect(sections.playing.map(\.bundleID) == ["x"])
    }

    @Test func ghostReturnsToSamePinnedIndex() {
        let pinned = ["a", "gone", "c"]
        let (ghosted, _) = AppListLayout.layout(
            apps: [
                app("a", name: "A", playing: false, pid: 1),
                app("c", name: "C", playing: false, pid: 2),
            ],
            pinnedIDs: pinned,
            audibleLevels: [:],
            metadataName: { $0 == "gone" ? "Gone" : nil },
            state: .init(),
            now: 0
        )
        #expect(ghosted.pinned.map(\.bundleID) == ["a", "gone", "c"])

        let (live, _) = AppListLayout.layout(
            apps: [
                app("a", name: "A", playing: false, pid: 1),
                app("gone", name: "Gone", playing: true, pid: 2),
                app("c", name: "C", playing: false, pid: 3),
            ],
            pinnedIDs: pinned,
            audibleLevels: ["gone": 0.5],
            metadataName: { _ in nil },
            state: .init(),
            now: 1
        )
        #expect(live.pinned.map(\.bundleID) == ["a", "gone", "c"])
        if case .live(let returnedApp) = live.pinned[1] {
            #expect(returnedApp.bundleID == "gone")
        } else {
            Issue.record("expected live at index 1")
        }
    }

    @Test func missingPinBecomesGhost() {
        let (sections, _) = AppListLayout.layout(
            apps: [],
            pinnedIDs: ["gone"],
            audibleLevels: [:],
            metadataName: { $0 == "gone" ? "GoneApp" : nil },
            state: .init(),
            now: 0
        )
        #expect(sections.pinned == [.ghost(bundleID: "gone", name: "GoneApp")])
    }

    @Test func ghostFallsBackToBundleID() {
        let (sections, _) = AppListLayout.layout(
            apps: [],
            pinnedIDs: ["com.acme.app"],
            audibleLevels: [:],
            metadataName: { _ in nil },
            state: .init(),
            now: 0
        )
        #expect(sections.pinned == [.ghost(bundleID: "com.acme.app", name: "com.acme.app")])
    }

    @Test func silentUsesLocalizedStandardCompareOrder() {
        let apps = [
            app("b", name: "Яндекс", playing: false, pid: 1),
            app("a", name: "Аура", playing: false, pid: 2),
        ]
        let (sections, _) = AppListLayout.layout(
            apps: apps,
            pinnedIDs: [],
            audibleLevels: [:],
            metadataName: { _ in nil },
            state: .init(),
            now: 0
        )
        #expect(sections.silent.map(\.name) == ["Аура", "Яндекс"])
    }

    @Test func eachLiveAppInExactlyOneSection() {
        let apps = [
            app("p", name: "P", playing: true, pid: 1),
            app("q", name: "Q", playing: true, pid: 2),
            app("r", name: "R", playing: false, pid: 3),
        ]
        let (sections, _) = AppListLayout.layout(
            apps: apps,
            pinnedIDs: ["p"],
            audibleLevels: ["p": 1, "q": 0.2],
            metadataName: { _ in nil },
            state: .init(),
            now: 0
        )
        let ids =
            sections.pinned.map(\.bundleID)
            + sections.playing.map(\.bundleID)
            + sections.silent.map(\.bundleID)
        #expect(Set(ids) == Set(["p", "q", "r"]))
        #expect(ids.count == 3)
    }

    @Test func audibleLevelMuteOverride() {
        #expect(AppListLayout.audibleLevel(level: 0.8, muted: true) == 0)
        #expect(AppListLayout.audibleLevel(level: 0.8, muted: false) == 0.8)
    }

    @Test func bucketIdealOrderThreeAppLadder() {
        let a = app("a", name: "A", playing: true, pid: 1)
        let b = app("b", name: "B", playing: true, pid: 2)
        let c = app("c", name: "C", playing: true, pid: 3)
        // Pairwise deltas are below minDelta, but the levels occupy buckets 16, 17, and 18.
        let ordered = AppListLayout.idealPlayingOrder(
            apps: [a, b, c],
            levels: ["a": 0.50, "b": 0.52, "c": 0.54]
        )
        #expect(ordered.map(\.bundleID) == ["c", "b", "a"])
    }

    @Test func shortSpikeDoesNotReorder() {
        let a = app("a", name: "A", playing: true)
        let b = app("b", name: "B", playing: true)
        var state = PlayingOrderState(appliedPlayingIDs: ["a", "b"])
        var result = AppListLayout.layout(
            apps: [a, b],
            pinnedIDs: [],
            audibleLevels: ["a": 0.2, "b": 0.9],
            metadataName: { _ in nil },
            state: state,
            now: 0
        )
        #expect(result.0.playing.map(\.bundleID) == ["a", "b"])
        state = result.1
        result = AppListLayout.layout(
            apps: [a, b],
            pinnedIDs: [],
            audibleLevels: ["a": 0.2, "b": 0.9],
            metadataName: { _ in nil },
            state: state,
            now: 0.5
        )
        #expect(result.0.playing.map(\.bundleID) == ["a", "b"])
    }

    @Test func stableOrderAppliesAfterHold() {
        let a = app("a", name: "A", playing: true)
        let b = app("b", name: "B", playing: true)
        var state = PlayingOrderState(appliedPlayingIDs: ["a", "b"])
        var result = AppListLayout.layout(
            apps: [a, b],
            pinnedIDs: [],
            audibleLevels: ["a": 0.2, "b": 0.9],
            metadataName: { _ in nil },
            state: state,
            now: 0
        )
        state = result.1
        result = AppListLayout.layout(
            apps: [a, b],
            pinnedIDs: [],
            audibleLevels: ["a": 0.2, "b": 0.9],
            metadataName: { _ in nil },
            state: state,
            now: 0.76
        )
        #expect(result.0.playing.map(\.bundleID) == ["b", "a"])
    }

    @Test func membershipChangeAppliesImmediately() {
        let a = app("a", name: "A", playing: true)
        let b = app("b", name: "B", playing: true)
        let state = PlayingOrderState(appliedPlayingIDs: ["a"])
        let (sections, newState) = AppListLayout.layout(
            apps: [a, b],
            pinnedIDs: [],
            audibleLevels: ["a": 0.1, "b": 0.9],
            metadataName: { _ in nil },
            state: state,
            now: 10
        )
        #expect(sections.playing.map(\.bundleID) == ["b", "a"])
        #expect(newState.candidatePlayingIDs == nil)
    }

    @Test func sameBucketDoesNotStartCandidate() {
        let a = app("a", name: "A", playing: true)
        let b = app("b", name: "B", playing: true)
        let state = PlayingOrderState(appliedPlayingIDs: ["a", "b"])
        let (sections, newState) = AppListLayout.layout(
            apps: [a, b],
            pinnedIDs: [],
            audibleLevels: ["a": 0.48, "b": 0.50],
            metadataName: { _ in nil },
            state: state,
            now: 0
        )
        #expect(sections.playing.map(\.bundleID) == ["a", "b"])
        #expect(newState.candidatePlayingIDs == nil)
    }

    @Test func candidateResetsWhenIdealChangesMidHold() {
        let a = app("a", name: "A", playing: true)
        let b = app("b", name: "B", playing: true)
        let c = app("c", name: "C", playing: true)
        var state = PlayingOrderState(appliedPlayingIDs: ["a", "b", "c"])
        var result = AppListLayout.layout(
            apps: [a, b, c],
            pinnedIDs: [],
            audibleLevels: ["a": 0.1, "b": 0.9, "c": 0.2],
            metadataName: { _ in nil },
            state: state,
            now: 0
        )
        state = result.1
        #expect(state.candidatePlayingIDs != nil)

        result = AppListLayout.layout(
            apps: [a, b, c],
            pinnedIDs: [],
            audibleLevels: ["a": 0.1, "b": 0.2, "c": 0.9],
            metadataName: { _ in nil },
            state: state,
            now: 0.4
        )
        state = result.1
        #expect(result.0.playing.map(\.bundleID) == ["a", "b", "c"])
        #expect(state.candidateSince == 0.4)

        result = AppListLayout.layout(
            apps: [a, b, c],
            pinnedIDs: [],
            audibleLevels: ["a": 0.1, "b": 0.2, "c": 0.9],
            metadataName: { _ in nil },
            state: state,
            now: 1.2
        )
        #expect(result.0.playing.map(\.bundleID) == ["c", "b", "a"])
    }

    @Test func candidateRestartsWhenLowerPositionsChangeMidHold() {
        let a = app("a", name: "A", playing: true)
        let b = app("b", name: "B", playing: true)
        let c = app("c", name: "C", playing: true)
        var state = PlayingOrderState(appliedPlayingIDs: ["a", "b", "c"])

        var result = AppListLayout.layout(
            apps: [a, b, c],
            pinnedIDs: [],
            audibleLevels: ["a": 0.1, "b": 0.5, "c": 0.9],
            metadataName: { _ in nil },
            state: state,
            now: 0
        )
        state = result.1
        #expect(result.0.playing.map(\.bundleID) == ["a", "b", "c"])
        #expect(state.candidatePlayingIDs == ["c", "b", "a"])
        #expect(state.candidateSince == 0)

        result = AppListLayout.layout(
            apps: [a, b, c],
            pinnedIDs: [],
            audibleLevels: ["a": 0.5, "b": 0.2, "c": 0.9],
            metadataName: { _ in nil },
            state: state,
            now: 0.4
        )
        state = result.1
        #expect(result.0.playing.map(\.bundleID) == ["a", "b", "c"])
        #expect(state.candidatePlayingIDs == ["c", "a", "b"])
        #expect(state.candidateSince == 0.4)

        result = AppListLayout.layout(
            apps: [a, b, c],
            pinnedIDs: [],
            audibleLevels: ["a": 0.5, "b": 0.2, "c": 0.9],
            metadataName: { _ in nil },
            state: state,
            now: 1.0
        )
        #expect(result.0.playing.map(\.bundleID) == ["a", "b", "c"])

        result = AppListLayout.layout(
            apps: [a, b, c],
            pinnedIDs: [],
            audibleLevels: ["a": 0.5, "b": 0.2, "c": 0.9],
            metadataName: { _ in nil },
            state: result.1,
            now: 1.2
        )
        #expect(result.0.playing.map(\.bundleID) == ["c", "a", "b"])
    }

    @Test func emptyStateAppliesIdealImmediately() {
        let a = app("a", name: "A", playing: true, pid: 1)
        let b = app("b", name: "B", playing: true, pid: 2)
        let (sections, state) = AppListLayout.layout(
            apps: [a, b],
            pinnedIDs: [],
            audibleLevels: ["a": 0.1, "b": 0.9],
            metadataName: { _ in nil },
            state: .init(),
            now: 0
        )
        #expect(sections.playing.map(\.bundleID) == ["b", "a"])
        #expect(state.appliedPlayingIDs == ["b", "a"])
        #expect(state.candidatePlayingIDs == nil)
    }
}
