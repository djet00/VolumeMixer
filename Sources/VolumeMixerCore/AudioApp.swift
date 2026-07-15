import AppKit
import CoreAudio

/// Один аудиопроцесс CoreAudio, атрибутированный приложению.
public struct AudioProcess: Identifiable, Equatable {
    public var id: pid_t { pid }
    public let pid: pid_t
    public let objectID: AudioObjectID
    public let bundleID: String
    public let name: String
    public let icon: NSImage?
    public let isPlaying: Bool

    public init(pid: pid_t, objectID: AudioObjectID, bundleID: String, name: String, icon: NSImage?, isPlaying: Bool) {
        self.pid = pid
        self.objectID = objectID
        self.bundleID = bundleID
        self.name = name
        self.icon = icon
        self.isPlaying = isPlaying
    }

    // Иконка сознательно не участвует в сравнении
    public static func == (l: AudioProcess, r: AudioProcess) -> Bool {
        l.pid == r.pid && l.objectID == r.objectID && l.bundleID == r.bundleID
            && l.name == r.name && l.isPlaying == r.isPlaying
    }
}

/// Строка в панели: приложение (по bundle ID) со всеми его аудиопроцессами.
/// У браузера может быть несколько процессов-хелперов — пользователь видит одну строку.
public struct AudioApp: Identifiable, Equatable {
    public var id: String { bundleID }
    public let bundleID: String
    public let name: String
    public let icon: NSImage?
    public let isPlaying: Bool
    public let processes: [AudioProcess]

    /// Группирует процессы по bundle ID. Играющие приложения — первыми,
    /// внутри групп — по алфавиту.
    public static func grouped(from processes: [AudioProcess]) -> [AudioApp] {
        let byBundle = Dictionary(grouping: processes, by: \.bundleID)
        let apps = byBundle.map { bundleID, procs in
            AudioApp(
                bundleID: bundleID,
                name: procs[0].name,
                icon: procs.first(where: { $0.icon != nil })?.icon,
                isPlaying: procs.contains(where: \.isPlaying),
                processes: procs.sorted { $0.pid < $1.pid }
            )
        }
        return apps.sorted {
            if $0.isPlaying != $1.isPlaying { return $0.isPlaying }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    public static func == (l: AudioApp, r: AudioApp) -> Bool {
        l.bundleID == r.bundleID && l.name == r.name && l.isPlaying == r.isPlaying
            && l.processes == r.processes
    }
}

public struct ProcessDiff: Equatable {
    public let added: [AudioProcess]
    public let removed: [AudioProcess]

    public static func between(old: [AudioProcess], new: [AudioProcess]) -> ProcessDiff {
        // Ключ — пара (pid, objectID): CoreAudio может пересоздать объект
        // процесса с тем же pid, тогда старый tap мёртв и контроллер
        // нужно пересоздать (remove + add).
        let oldKeys = Set(old.map { "\($0.pid):\($0.objectID)" })
        let newKeys = Set(new.map { "\($0.pid):\($0.objectID)" })
        return ProcessDiff(
            added: new.filter { !oldKeys.contains("\($0.pid):\($0.objectID)") },
            removed: old.filter { !newKeys.contains("\($0.pid):\($0.objectID)") }
        )
    }
}
