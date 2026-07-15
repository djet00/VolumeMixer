import AppKit
import Combine
import CoreAudio

@MainActor
public final class AudioEngine: ObservableObject {
    @Published public private(set) var apps: [AudioApp] = []
    @Published public private(set) var permissionGranted = true

    private var controllers: [pid_t: ProcessTapController] = [:]
    private let monitor = AudioProcessMonitor()
    private let settings: SettingsStore
    private var deviceListener: PropertyListener?
    private var started = false

    public init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
    }

    public func start() {
        guard !started else { return }
        started = true
        permissionGranted = AudioPermission.preflight()

        monitor.onChange = { [weak self] apps in
            Task { @MainActor in self?.sync(apps) }
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

    // MARK: - Управление

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
    }

    public func volume(for app: AudioApp) -> Float { settings.settings(for: app.bundleID).volume }
    public func isMuted(_ app: AudioApp) -> Bool { settings.settings(for: app.bundleID).muted }
    public func level(for app: AudioApp) -> Float { controllers[app.id]?.level ?? 0 }
    public func hasController(for app: AudioApp) -> Bool { controllers[app.id] != nil }

    // MARK: - Внутреннее

    private func sync(_ newApps: [AudioApp]) {
        guard newApps != apps else { return } // поллинг: без изменений не публикуем
        let diff = ProcessDiff.between(old: apps, new: newApps)
        for app in diff.removed {
            NSLog("Микшер: − %@ (pid %d)", app.name, app.id)
            controllers[app.id]?.invalidate()
            controllers[app.id] = nil
        }
        for app in diff.added {
            createController(for: app)
        }
        apps = newApps
    }

    private func createController(for app: AudioApp) {
        let s = settings.settings(for: app.bundleID)
        let gain = s.muted ? 0 : VolumeCurve.gain(fromSlider: s.volume)
        do {
            controllers[app.id] = try ProcessTapController(app: app, initialGain: gain)
            NSLog("Микшер: + %@ (pid %d, oid %u)", app.name, app.id, app.objectID)
        } catch {
            NSLog("Микшер: не удалось создать tap для \(app.name): \(error)")
            permissionGranted = AudioPermission.preflight()
        }
    }

    private func applyGain(for app: AudioApp) {
        let s = settings.settings(for: app.bundleID)
        controllers[app.id]?.setGain(s.muted ? 0 : VolumeCurve.gain(fromSlider: s.volume))
    }

    private func rebuildAll() {
        let current = apps
        for (_, c) in controllers { c.invalidate() }
        controllers = [:]
        for app in current { createController(for: app) }
    }
}
