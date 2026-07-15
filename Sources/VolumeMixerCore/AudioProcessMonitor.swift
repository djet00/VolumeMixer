import CoreAudio
import AppKit

/// Следит за списком аудиопроцессов CoreAudio и отдаёт те, что сейчас
/// воспроизводят звук, в виде [AudioApp] (без собственного процесса).
public final class AudioProcessMonitor {
    public var onChange: (([AudioApp]) -> Void)?

    private var listListener: PropertyListener?
    private var perProcessListeners: [AudioObjectID: PropertyListener] = [:]
    private var refreshScheduled = false
    private let ownPID = getpid()

    public init() {}

    public func start() {
        listListener = PropertyListener(
            objectID: .system,
            selector: kAudioHardwarePropertyProcessObjectList
        ) { [weak self] in self?.scheduleRefresh() }
        refresh()
    }

    public func currentApps() -> [AudioApp] {
        let objectIDs = (try? AudioObjectID.system.readObjectIDs(kAudioHardwarePropertyProcessObjectList)) ?? []
        var apps: [AudioApp] = []
        var seenObjects = Set<AudioObjectID>()

        for oid in objectIDs {
            seenObjects.insert(oid)
            // Подписка на старт/стоп вывода каждого процесса
            if perProcessListeners[oid] == nil {
                perProcessListeners[oid] = PropertyListener(
                    objectID: oid,
                    selector: kAudioProcessPropertyIsRunningOutput
                ) { [weak self] in self?.scheduleRefresh() }
            }
            guard let pid = try? oid.readInt32(kAudioProcessPropertyPID), pid != ownPID else { continue }
            guard let running = try? oid.readUInt32(kAudioProcessPropertyIsRunningOutput), running == 1 else { continue }
            guard let app = NSRunningApplication(processIdentifier: pid) ?? responsibleApp(for: pid),
                  let bundleID = app.bundleID_nonEmpty else { continue }
            apps.append(AudioApp(
                id: pid,
                objectID: oid,
                bundleID: bundleID,
                name: app.localizedName ?? bundleID,
                icon: app.icon
            ))
        }
        perProcessListeners = perProcessListeners.filter { seenObjects.contains($0.key) }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Хелперы Chrome и подобных: сам процесс — не приложение,
    /// поднимаемся по цепочке родителей до запущенного приложения.
    private func responsibleApp(for pid: pid_t) -> NSRunningApplication? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }
        let ppid = info.kp_eproc.e_ppid
        guard ppid > 1 else { return nil }
        return NSRunningApplication(processIdentifier: ppid) ?? responsibleApp(for: ppid)
    }

    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.refreshScheduled = false
            self?.refresh()
        }
    }

    private func refresh() {
        onChange?(currentApps())
    }
}

private extension NSRunningApplication {
    var bundleID_nonEmpty: String? {
        guard let b = bundleIdentifier, !b.isEmpty else { return nil }
        return b
    }
}
