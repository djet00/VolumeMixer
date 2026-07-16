import AppKit
import Combine
import CoreAudio

@MainActor
public final class AudioEngine: ObservableObject {
    @Published public private(set) var apps: [AudioApp] = []
    @Published public private(set) var permissionGranted = true
    @Published public private(set) var sections = AppListSections()

    private var controllers: [pid_t: ProcessTapController] = [:]
    private var playingProcesses: [AudioProcess] = []
    private let monitor = AudioProcessMonitor()
    private let settings: SettingsStore
    private var deviceListener: PropertyListener?
    private var started = false
    private var orderState = PlayingOrderState()

    public init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
    }

    public func start() {
        guard !started else { return }
        started = true
        permissionGranted = AudioPermission.preflight()

        monitor.onChange = { [weak self] processes in
            Task { @MainActor in self?.sync(processes) }
        }
        monitor.start()

        // Смена устройства вывода → пересоздать всю цепочку
        deviceListener = PropertyListener(
            objectID: .system,
            selector: kAudioHardwarePropertyDefaultOutputDevice
        ) { [weak self] in
            Task { @MainActor in self?.rebuildAll() }
        }
    }

    public func recheckPermission() {
        permissionGranted = AudioPermission.preflight()
        if permissionGranted { rebuildAll() }
    }

    // MARK: - Управление (по приложению, т.е. по bundle ID)

    public func setVolume(_ slider: Float, for app: AudioApp) {
        var s = settings.settings(for: app.bundleID)
        s.volume = slider
        settings.set(s, for: app.bundleID)
        applyGain(for: app)
    }

    public func setMuted(_ muted: Bool, for app: AudioApp) {
        var s = settings.settings(for: app.bundleID)
        s.muted = muted
        settings.set(s, for: app.bundleID)
        applyGain(for: app)
        objectWillChange.send()
        relayout()
    }

    public func volume(for app: AudioApp) -> Float { settings.settings(for: app.bundleID).volume }
    public func isMuted(_ app: AudioApp) -> Bool { settings.settings(for: app.bundleID).muted }

    /// Уровень VU приложения — максимум по его играющим процессам.
    public func level(for app: AudioApp) -> Float {
        app.processes.compactMap { controllers[$0.pid]?.level }.max() ?? 0
    }

    public func audibleLevel(for app: AudioApp) -> Float {
        AppListLayout.audibleLevel(level: level(for: app), muted: isMuted(app))
    }

    public func canPin(_ app: AudioApp) -> Bool {
        settings.canPin(bundleID: app.bundleID)
    }

    @discardableResult
    public func pin(_ app: AudioApp) -> Bool {
        let ok = settings.pin(bundleID: app.bundleID, name: app.name)
        if ok { relayout() }
        return ok
    }

    public func unpin(bundleID: String) {
        settings.unpin(bundleID: bundleID)
        relayout()
    }

    public func movePinned(bundleID: String, direction: PinMoveDirection) {
        settings.movePinned(bundleID: bundleID, direction: direction)
        relayout()
    }

    public func relayout(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        let pinnedIDs = settings.pinnedBundleIDs
        let pinnedIDSet = Set(pinnedIDs)
        var audibleLevels: [String: Float] = [:]
        for app in apps where app.isPlaying && !pinnedIDSet.contains(app.bundleID) {
            audibleLevels[app.bundleID] = audibleLevel(for: app)
        }

        let result = AppListLayout.layout(
            apps: apps,
            pinnedIDs: pinnedIDs,
            audibleLevels: audibleLevels,
            metadataName: { settings.pinMetadata(for: $0)?.name },
            state: orderState,
            now: now
        )
        orderState = result.1
        if result.0 != sections { sections = result.0 }
    }

    /// true, если у играющего приложения не удалось создать ни одного tap'а.
    public func tapFailed(for app: AudioApp) -> Bool {
        app.isPlaying && !app.processes.contains { controllers[$0.pid] != nil }
    }

    // MARK: - Внутреннее

    private func sync(_ processes: [AudioProcess]) {
        let playing = processes.filter(\.isPlaying)
        let diff = ProcessDiff.between(old: playingProcesses, new: playing)
        for proc in diff.removed {
            NSLog("Микшер: − %@ (pid %d)", proc.name, proc.pid)
            controllers[proc.pid]?.invalidate()
            controllers[proc.pid] = nil
        }
        for proc in diff.added {
            createController(for: proc)
        }
        playingProcesses = playing

        let grouped = AudioApp.grouped(from: processes)
        if grouped != apps { apps = grouped }

        let pinnedIDs = Set(settings.pinnedBundleIDs)
        for app in grouped where pinnedIDs.contains(app.bundleID) {
            settings.updatePinMetadata(bundleID: app.bundleID, name: app.name)
        }
        relayout()
    }

    private func createController(for proc: AudioProcess) {
        let s = settings.settings(for: proc.bundleID)
        let gain = s.muted ? 0 : VolumeCurve.gain(fromSlider: s.volume)
        do {
            controllers[proc.pid] = try ProcessTapController(process: proc, initialGain: gain)
            NSLog("Микшер: + %@ (pid %d, oid %u)", proc.name, proc.pid, proc.objectID)
        } catch {
            NSLog("Микшер: не удалось создать tap для %@: %@", proc.name, "\(error)")
            permissionGranted = AudioPermission.preflight()
        }
    }

    private func applyGain(for app: AudioApp) {
        let s = settings.settings(for: app.bundleID)
        let gain = s.muted ? 0 : VolumeCurve.gain(fromSlider: s.volume)
        for proc in app.processes {
            controllers[proc.pid]?.setGain(gain)
        }
    }

    private func rebuildAll() {
        let current = playingProcesses
        for (_, c) in controllers { c.invalidate() }
        controllers = [:]
        for proc in current { createController(for: proc) }
    }
}
