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
        // Ключ — пара (pid, objectID): CoreAudio может пересоздать объект
        // процесса с тем же pid, тогда старый tap мёртв и контроллер
        // нужно пересоздать (remove + add).
        let oldKeys = Set(old.map { "\($0.id):\($0.objectID)" })
        let newKeys = Set(new.map { "\($0.id):\($0.objectID)" })
        return ProcessDiff(
            added: new.filter { !oldKeys.contains("\($0.id):\($0.objectID)") },
            removed: old.filter { !newKeys.contains("\($0.id):\($0.objectID)") }
        )
    }
}
