import Foundation

public enum AppListItem: Equatable, Identifiable {
    case live(AudioApp)
    case ghost(bundleID: String, name: String)

    public var id: String { bundleID }

    public var bundleID: String {
        switch self {
        case .live(let app):
            app.bundleID
        case .ghost(let bundleID, _):
            bundleID
        }
    }
}

public struct AppListSections: Equatable {
    public var pinned: [AppListItem]
    public var playing: [AudioApp]
    public var silent: [AudioApp]

    public init(
        pinned: [AppListItem] = [],
        playing: [AudioApp] = [],
        silent: [AudioApp] = []
    ) {
        self.pinned = pinned
        self.playing = playing
        self.silent = silent
    }
}

public struct PlayingOrderState: Equatable {
    public var appliedPlayingIDs: [String]
    public var candidatePlayingIDs: [String]?
    public var candidateSince: TimeInterval?

    public init(
        appliedPlayingIDs: [String] = [],
        candidatePlayingIDs: [String]? = nil,
        candidateSince: TimeInterval? = nil
    ) {
        self.appliedPlayingIDs = appliedPlayingIDs
        self.candidatePlayingIDs = candidatePlayingIDs
        self.candidateSince = candidateSince
    }
}

public enum AppListLayout {
    public static let holdDuration: TimeInterval = 0.75
    public static let minDelta: Float = 0.03

    public static func audibleLevel(level: Float, muted: Bool) -> Float {
        muted ? 0 : level
    }

    public static func idealPlayingOrder(
        apps: [AudioApp],
        levels: [String: Float]
    ) -> [AudioApp] {
        func bucket(_ level: Float) -> Int {
            Int((level / minDelta).rounded(.down))
        }

        return apps.sorted { first, second in
            let firstBucket = bucket(levels[first.bundleID] ?? 0)
            let secondBucket = bucket(levels[second.bundleID] ?? 0)
            if firstBucket != secondBucket {
                return firstBucket > secondBucket
            }

            let nameOrder = first.name.localizedStandardCompare(second.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            return first.bundleID < second.bundleID
        }
    }

    public static func layout(
        apps: [AudioApp],
        pinnedIDs: [String],
        audibleLevels: [String: Float],
        metadataName: (String) -> String?,
        state: PlayingOrderState,
        now: TimeInterval
    ) -> (AppListSections, PlayingOrderState) {
        let appsByBundleID = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID, $0) })
        let pinned = pinnedIDs.map { bundleID -> AppListItem in
            if let app = appsByBundleID[bundleID] {
                return .live(app)
            }
            return .ghost(
                bundleID: bundleID,
                name: metadataName(bundleID) ?? bundleID
            )
        }

        let pinnedIDSet = Set(pinnedIDs)
        let unpinnedApps = apps.filter { !pinnedIDSet.contains($0.bundleID) }
        let idealPlaying = idealPlayingOrder(
            apps: unpinnedApps.filter(\.isPlaying),
            levels: audibleLevels
        )
        let idealPlayingIDs = idealPlaying.map(\.bundleID)
        let appliedPlayingIDs = state.appliedPlayingIDs
        let playing: [AudioApp]
        let nextState: PlayingOrderState

        if Set(appliedPlayingIDs) != Set(idealPlayingIDs) {
            playing = idealPlaying
            nextState = PlayingOrderState(appliedPlayingIDs: idealPlayingIDs)
        } else if idealPlayingIDs == appliedPlayingIDs {
            playing = idealPlaying
            nextState = PlayingOrderState(appliedPlayingIDs: appliedPlayingIDs)
        } else {
            let appsByPlayingID = Dictionary(
                uniqueKeysWithValues: idealPlaying.map { ($0.bundleID, $0) }
            )
            let appliedPlaying = appliedPlayingIDs.compactMap { appsByPlayingID[$0] }

            if state.candidatePlayingIDs == idealPlayingIDs,
               let candidateSince = state.candidateSince,
               now - candidateSince >= holdDuration
            {
                playing = idealPlaying
                nextState = PlayingOrderState(appliedPlayingIDs: idealPlayingIDs)
            } else if state.candidatePlayingIDs == idealPlayingIDs,
                      state.candidateSince != nil
            {
                playing = appliedPlaying
                nextState = state
            } else {
                playing = appliedPlaying
                nextState = PlayingOrderState(
                    appliedPlayingIDs: appliedPlayingIDs,
                    candidatePlayingIDs: idealPlayingIDs,
                    candidateSince: now
                )
            }
        }

        let silent = unpinnedApps
            .filter { !$0.isPlaying }
            .sorted { first, second in
                let nameOrder = first.name.localizedStandardCompare(second.name)
                if nameOrder != .orderedSame {
                    return nameOrder == .orderedAscending
                }
                return first.bundleID < second.bundleID
            }

        return (
            AppListSections(pinned: pinned, playing: playing, silent: silent),
            nextState
        )
    }
}
