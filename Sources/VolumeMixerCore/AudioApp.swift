import AppKit
import CoreAudio

public struct AudioApp: Identifiable, Equatable {
    public let id: pid_t
    public let objectID: AudioObjectID
    public let bundleID: String
    public let name: String
    public let icon: NSImage?

    public init(id: pid_t, objectID: AudioObjectID, bundleID: String, name: String, icon: NSImage?) {
        self.id = id
        self.objectID = objectID
        self.bundleID = bundleID
        self.name = name
        self.icon = icon
    }

    // Иконка сознательно не участвует в сравнении
    public static func == (l: AudioApp, r: AudioApp) -> Bool {
        l.id == r.id && l.objectID == r.objectID && l.bundleID == r.bundleID && l.name == r.name
    }
}

public struct ProcessDiff: Equatable {
    public let added: [AudioApp]
    public let removed: [AudioApp]

    public static func between(old: [AudioApp], new: [AudioApp]) -> ProcessDiff {
        let oldIDs = Set(old.map(\.id))
        let newIDs = Set(new.map(\.id))
        return ProcessDiff(
            added: new.filter { !oldIDs.contains($0.id) },
            removed: old.filter { !newIDs.contains($0.id) }
        )
    }
}
