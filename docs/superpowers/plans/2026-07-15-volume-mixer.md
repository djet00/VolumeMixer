# Микшер громкости для macOS — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menu bar приложение для macOS с независимой громкостью каждого играющего звук приложения (ползунок + mute + VU-метр), мастер-громкостью и запоминанием настроек.

**Architecture:** SPM-пакет: библиотека `VolumeMixerCore` (вся логика: CoreAudio process taps, монитор процессов, настройки) + тонкий executable `VolumeMixerApp` (SwiftUI `MenuBarExtra`). На каждое играющее приложение — muted-tap плюс приватное агрегатное устройство; IOProc копирует сэмплы tap→выход с атомарным gain и считает RMS для VU.

**Tech Stack:** Swift 6.3 (CLT, без Xcode), SwiftUI + AppKit, CoreAudio process taps (macOS 14.4+ API), Synchronization (Atomic), swift-testing.

## Global Constraints

- Сборка только через `swift build` / SPM — Xcode на машине нет.
- Тесты только на swift-testing (`import Testing`) — XCTest без Xcode недоступен.
- Платформа пакета: `.macOS("15.0")` (нужен фреймворк Synchronization; машина — 26.5).
- Язык таргетов: `.swiftLanguageMode(.v5)` (CoreAudio-коллбеки со строгим Swift 6 не воюем).
- Никаких внешних зависимостей — только системные фреймворки.
- UI на русском. Имя приложения: `Микшер громкости.app`, executable `VolumeMixer`, bundle ID `ru.mikhail.VolumeMixer`.
- Подпись ad-hoc (`codesign --sign -`), идентификатор стабильный (для TCC).
- В аудио-callback'ах никаких блокировок/аллокаций — только атомики и работа с буферами.
- Собственный процесс (getpid()) никогда не показывается и не тапается (иначе петля).
- Коммит после каждой задачи.

---

### Task 1: SPM-скелет + пустая панель в menu bar + сборка .app

**Files:**
- Create: `Package.swift`, `.gitignore`, `Resources/Info.plist`, `build.sh`
- Create: `Sources/VolumeMixerCore/VolumeCurve.swift` (заглушка-якорь, чтобы таргет собирался)
- Create: `Sources/VolumeMixerApp/VolumeMixerApp.swift`
- Test: `Tests/VolumeMixerCoreTests/VolumeCurveTests.swift` (пустой smoke-тест)

**Interfaces:**
- Produces: собирающийся пакет; `./build.sh` кладёт готовый `build/Микшер громкости.app`.

- [ ] **Step 1: Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VolumeMixer",
    platforms: [.macOS("15.0")],
    targets: [
        .target(
            name: "VolumeMixerCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "VolumeMixerApp",
            dependencies: ["VolumeMixerCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "VolumeMixerCoreTests",
            dependencies: ["VolumeMixerCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
```

`.gitignore`:

```
.build/
build/
.DS_Store
```

- [ ] **Step 2: заглушка ядра и smoke-тест**

`Sources/VolumeMixerCore/VolumeCurve.swift`:

```swift
public enum VolumeCurve {}
```

`Tests/VolumeMixerCoreTests/VolumeCurveTests.swift`:

```swift
import Testing
@testable import VolumeMixerCore

@Test func packageBuilds() {
    #expect(true)
}
```

- [ ] **Step 3: минимальное приложение**

`Sources/VolumeMixerApp/VolumeMixerApp.swift`:

```swift
import SwiftUI

@main
struct VolumeMixerApp: App {
    var body: some Scene {
        MenuBarExtra("Микшер громкости", systemImage: "slider.vertical.3") {
            Text("Скоро здесь будет микшер")
                .padding()
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 4: Info.plist и build.sh**

`Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>ru.mikhail.VolumeMixer</string>
    <key>CFBundleName</key><string>Микшер громкости</string>
    <key>CFBundleDisplayName</key><string>Микшер громкости</string>
    <key>CFBundleExecutable</key><string>VolumeMixer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAudioCaptureUsageDescription</key>
    <string>Микшеру нужен доступ к системному звуку, чтобы регулировать громкость отдельных приложений.</string>
</dict>
</plist>
```

`build.sh`:

```bash
#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="build/Микшер громкости.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/VolumeMixerApp" "$APP/Contents/MacOS/VolumeMixer"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - --identifier ru.mikhail.VolumeMixer "$APP"
echo "Готово: $APP"
```

`chmod +x build.sh`

- [ ] **Step 5: проверить**

Run: `swift test` → PASS (1 тест). Run: `./build.sh` → «Готово: …». Run: `open "build/Микшер громкости.app"` → в menu bar появляется иконка слайдеров, по клику панель с заглушкой. `pkill -f 'МикшерMacOS|VolumeMixer' || true` после проверки.

- [ ] **Step 6: Commit** `feat: скелет SPM, menu bar заглушка, сборка .app`

---

### Task 2: VolumeCurve — перцептивная кривая громкости (TDD)

**Files:**
- Modify: `Sources/VolumeMixerCore/VolumeCurve.swift`
- Test: `Tests/VolumeMixerCoreTests/VolumeCurveTests.swift`

**Interfaces:**
- Produces: `VolumeCurve.gain(fromSlider: Float) -> Float`, `VolumeCurve.slider(fromGain: Float) -> Float`.

- [ ] **Step 1: тесты**

```swift
import Testing
@testable import VolumeMixerCore

@Suite struct VolumeCurveTests {
    @Test func extremes() {
        #expect(VolumeCurve.gain(fromSlider: 0) == 0)
        #expect(VolumeCurve.gain(fromSlider: 1) == 1)
    }
    @Test func perceptualSquare() {
        #expect(abs(VolumeCurve.gain(fromSlider: 0.5) - 0.25) < 0.0001)
    }
    @Test func clamping() {
        #expect(VolumeCurve.gain(fromSlider: -1) == 0)
        #expect(VolumeCurve.gain(fromSlider: 2) == 1)
    }
    @Test func roundtrip() {
        for p: Float in [0, 0.1, 0.33, 0.5, 0.77, 1] {
            #expect(abs(VolumeCurve.slider(fromGain: VolumeCurve.gain(fromSlider: p)) - p) < 0.0001)
        }
    }
}
```

- [ ] **Step 2: `swift test`** → FAIL (нет функций)
- [ ] **Step 3: реализация**

```swift
import Foundation

public enum VolumeCurve {
    /// Позиция ползунка 0…1 → линейный коэффициент усиления 0…1.
    /// Квадратичная кривая: середина ползунка ощущается как «вдвое тише».
    public static func gain(fromSlider position: Float) -> Float {
        let p = min(max(position, 0), 1)
        return p * p
    }

    public static func slider(fromGain gain: Float) -> Float {
        let g = min(max(gain, 0), 1)
        return sqrt(g)
    }
}
```

- [ ] **Step 4: `swift test`** → PASS
- [ ] **Step 5: Commit** `feat: перцептивная кривая громкости`

---

### Task 3: SettingsStore — персистентность настроек (TDD)

**Files:**
- Create: `Sources/VolumeMixerCore/SettingsStore.swift`
- Test: `Tests/VolumeMixerCoreTests/SettingsStoreTests.swift`

**Interfaces:**
- Produces: `AppAudioSettings(volume: Float, muted: Bool)`; `SettingsStore(defaults:)` с `settings(for bundleID: String) -> AppAudioSettings` и `set(_:for:)`. По умолчанию volume 1.0, muted false.

- [ ] **Step 1: тесты**

```swift
import Testing
import Foundation
@testable import VolumeMixerCore

@Suite struct SettingsStoreTests {
    private func freshDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func defaultsForUnknownApp() {
        let store = SettingsStore(defaults: freshDefaults())
        let s = store.settings(for: "com.example.unknown")
        #expect(s.volume == 1.0)
        #expect(s.muted == false)
    }

    @Test func savesAndReads() {
        let d = freshDefaults()
        let store = SettingsStore(defaults: d)
        store.set(AppAudioSettings(volume: 0.3, muted: true), for: "com.spotify.client")
        let s = store.settings(for: "com.spotify.client")
        #expect(abs(s.volume - 0.3) < 0.0001)
        #expect(s.muted == true)
    }

    @Test func survivesNewStoreInstance() {
        let d = freshDefaults()
        SettingsStore(defaults: d).set(AppAudioSettings(volume: 0.5, muted: false), for: "a.b.c")
        let s = SettingsStore(defaults: d).settings(for: "a.b.c")
        #expect(abs(s.volume - 0.5) < 0.0001)
    }

    @Test func independentApps() {
        let store = SettingsStore(defaults: freshDefaults())
        store.set(AppAudioSettings(volume: 0.1, muted: false), for: "app.one")
        #expect(store.settings(for: "app.two").volume == 1.0)
    }
}
```

- [ ] **Step 2: `swift test`** → FAIL
- [ ] **Step 3: реализация**

```swift
import Foundation

public struct AppAudioSettings: Codable, Equatable {
    public var volume: Float   // позиция ползунка 0…1
    public var muted: Bool

    public init(volume: Float = 1.0, muted: Bool = false) {
        self.volume = volume
        self.muted = muted
    }
}

public final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "appAudioSettings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func settings(for bundleID: String) -> AppAudioSettings {
        all()[bundleID] ?? AppAudioSettings()
    }

    public func set(_ settings: AppAudioSettings, for bundleID: String) {
        var d = all()
        d[bundleID] = settings
        if let data = try? JSONEncoder().encode(d) {
            defaults.set(data, forKey: key)
        }
    }

    private func all() -> [String: AppAudioSettings] {
        guard let data = defaults.data(forKey: key),
              let d = try? JSONDecoder().decode([String: AppAudioSettings].self, from: data)
        else { return [:] }
        return d
    }
}
```

- [ ] **Step 4: `swift test`** → PASS
- [ ] **Step 5: Commit** `feat: хранилище настроек громкости по bundle ID`

---

### Task 4: модель AudioApp + диф списка процессов (TDD)

**Files:**
- Create: `Sources/VolumeMixerCore/AudioApp.swift`
- Test: `Tests/VolumeMixerCoreTests/ProcessDiffTests.swift`

**Interfaces:**
- Produces: `AudioApp` (id=pid, objectID, bundleID, name, icon: NSImage?; Equatable/Identifiable, icon не участвует в ==); `ProcessDiff.between(old:new:) -> ProcessDiff` с `added`/`removed` (по pid).

- [ ] **Step 1: тесты**

```swift
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
```

- [ ] **Step 2: `swift test`** → FAIL
- [ ] **Step 3: реализация**

```swift
import AppKit

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
```

(`AudioObjectID` доступен через `import AppKit`→CoreAudio? Нет: добавить `import CoreAudio` в файл.)

- [ ] **Step 4: `swift test`** → PASS
- [ ] **Step 5: Commit** `feat: модель AudioApp и диф списка процессов`

---

### Task 5: CoreAudio-хелперы + SystemVolume

**Files:**
- Create: `Sources/VolumeMixerCore/CoreAudioSupport.swift`
- Create: `Sources/VolumeMixerCore/SystemVolume.swift`

**Interfaces:**
- Produces (внутри модуля): `AudioObjectID.system`; `readUInt32/readInt32/readString/readObjectIDs/readFloat32/writeFloat32` throws-хелперы; `PropertyListener` (RAII-подписка на изменение свойства); `CoreAudioError`.
- Produces (public): `SystemVolume.defaultOutputDeviceID()`, `SystemVolume.getVolume() -> Float?`, `SystemVolume.setVolume(Float)`, `SystemVolume.defaultOutputDeviceUID() -> String`.

- [ ] **Step 1: CoreAudioSupport.swift**

```swift
import CoreAudio
import Foundation

enum CoreAudioError: Error, CustomStringConvertible {
    case osStatus(OSStatus, String)
    var description: String {
        if case let .osStatus(s, what) = self { return "CoreAudio: \(what) → \(s)" }
        return "CoreAudio error"
    }
}

func checkErr(_ status: OSStatus, _ what: String) throws {
    guard status == noErr else { throw CoreAudioError.osStatus(status, what) }
}

func propertyAddress(_ selector: AudioObjectPropertySelector,
                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                     element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
}

extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)
    static let unknown = AudioObjectID(kAudioObjectUnknown)

    func readUInt32(_ selector: AudioObjectPropertySelector,
                    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> UInt32 {
        var addr = propertyAddress(selector, scope: scope)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try checkErr(AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value), "read \(selector)")
        return value
    }

    func readInt32(_ selector: AudioObjectPropertySelector) throws -> Int32 {
        var addr = propertyAddress(selector)
        var value: Int32 = 0
        var size = UInt32(MemoryLayout<Int32>.size)
        try checkErr(AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value), "read \(selector)")
        return value
    }

    func readObjectID(_ selector: AudioObjectPropertySelector) throws -> AudioObjectID {
        try AudioObjectID(readUInt32(selector))
    }

    func readString(_ selector: AudioObjectPropertySelector) throws -> String {
        var addr = propertyAddress(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try checkErr(AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value), "read \(selector)")
        return value?.takeRetainedValue() as String? ?? ""
    }

    func readObjectIDs(_ selector: AudioObjectPropertySelector) throws -> [AudioObjectID] {
        var addr = propertyAddress(selector)
        var size: UInt32 = 0
        try checkErr(AudioObjectGetPropertyDataSize(self, &addr, 0, nil, &size), "size \(selector)")
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        guard count > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: count)
        try checkErr(AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &ids), "read \(selector)")
        return ids
    }

    func readFloat32(_ selector: AudioObjectPropertySelector,
                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                     element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) throws -> Float32 {
        var addr = propertyAddress(selector, scope: scope, element: element)
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        try checkErr(AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value), "read \(selector)")
        return value
    }

    func writeFloat32(_ selector: AudioObjectPropertySelector,
                      scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                      element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
                      value: Float32) throws {
        var addr = propertyAddress(selector, scope: scope, element: element)
        var v = value
        try checkErr(AudioObjectSetPropertyData(self, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v), "write \(selector)")
    }

    func hasProperty(_ selector: AudioObjectPropertySelector,
                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                     element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> Bool {
        var addr = propertyAddress(selector, scope: scope, element: element)
        return AudioObjectHasProperty(self, &addr)
    }
}

/// RAII-подписка на изменение свойства CoreAudio-объекта.
final class PropertyListener {
    private let objectID: AudioObjectID
    private var address: AudioObjectPropertyAddress
    private let queue: DispatchQueue
    private let block: AudioObjectPropertyListenerBlock

    init?(objectID: AudioObjectID,
          selector: AudioObjectPropertySelector,
          scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
          queue: DispatchQueue = .main,
          handler: @escaping () -> Void) {
        self.objectID = objectID
        self.address = propertyAddress(selector, scope: scope)
        self.queue = queue
        self.block = { _, _ in handler() }
        guard AudioObjectAddPropertyListenerBlock(objectID, &address, queue, block) == noErr else { return nil }
    }

    deinit {
        AudioObjectRemovePropertyListenerBlock(objectID, &address, queue, block)
    }
}
```

- [ ] **Step 2: SystemVolume.swift**

```swift
import CoreAudio
import Foundation

public enum SystemVolume {
    /// 'vmvc' — виртуальная главная громкость (kAudioHardwareServiceDeviceProperty_VirtualMainVolume).
    /// Задаём селектор числом, чтобы не зависеть от имени константы в SDK.
    private static let virtualMainVolume = AudioObjectPropertySelector(0x766D_7663)

    public static func defaultOutputDeviceID() throws -> AudioObjectID {
        try AudioObjectID.system.readObjectID(kAudioHardwarePropertyDefaultOutputDevice)
    }

    public static func defaultOutputDeviceUID() throws -> String {
        try defaultOutputDeviceID().readString(kAudioDevicePropertyDeviceUID)
    }

    public static func getVolume() -> Float? {
        guard let dev = try? defaultOutputDeviceID() else { return nil }
        let scope = kAudioObjectPropertyScopeOutput
        if dev.hasProperty(virtualMainVolume, scope: scope),
           let v = try? dev.readFloat32(virtualMainVolume, scope: scope) {
            return v
        }
        // Фолбэк: среднее по каналам 1 и 2
        let ch = [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)].compactMap {
            try? dev.readFloat32(kAudioDevicePropertyVolumeScalar, scope: scope, element: $0)
        }
        return ch.isEmpty ? nil : ch.reduce(0, +) / Float(ch.count)
    }

    public static func setVolume(_ volume: Float) {
        guard let dev = try? defaultOutputDeviceID() else { return }
        let v = min(max(volume, 0), 1)
        let scope = kAudioObjectPropertyScopeOutput
        if dev.hasProperty(virtualMainVolume, scope: scope),
           (try? dev.writeFloat32(virtualMainVolume, scope: scope, value: v)) != nil {
            return
        }
        for ch in [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)] {
            try? dev.writeFloat32(kAudioDevicePropertyVolumeScalar, scope: scope, element: ch, value: v)
        }
    }
}
```

- [ ] **Step 3: `swift build` → без ошибок; `swift test` → PASS (старые тесты)**
- [ ] **Step 4: Commit** `feat: CoreAudio-хелперы и системная громкость`

---

### Task 6: AudioProcessMonitor — кто сейчас играет звук

**Files:**
- Create: `Sources/VolumeMixerCore/AudioProcessMonitor.swift`

**Interfaces:**
- Consumes: хелперы из Task 5, `AudioApp` из Task 4.
- Produces: `AudioProcessMonitor` с `var onChange: (([AudioApp]) -> Void)?`, `func start()`, `func currentApps() -> [AudioApp]`. Отдаёт только процессы с `isRunningOutput == true`, исключая свой pid и процессы без bundle ID/NSRunningApplication.

- [ ] **Step 1: реализация**

```swift
import CoreAudio
import AppKit

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

    /// Хелперы Chrome и co.: сам процесс — не приложение, ищем родителя среди запущенных приложений.
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
```

- [ ] **Step 2: `swift build`** → без ошибок
- [ ] **Step 3: Commit** `feat: монитор аудиопроцессов`

---

### Task 7: ProcessTapController — tap + агрегат + IOProc с gain и VU

**Files:**
- Create: `Sources/VolumeMixerCore/ProcessTapController.swift`

**Interfaces:**
- Consumes: `SystemVolume.defaultOutputDeviceUID()`, `checkErr`, `AudioApp`.
- Produces: `ProcessTapController(app: AudioApp, initialGain: Float) throws`; `func setGain(_ Float)` (атомарно, mute = 0); `var level: Float` (сглаженный RMS 0…1); `func invalidate()`.

- [ ] **Step 1: реализация**

```swift
import CoreAudio
import Foundation
import Synchronization

/// Один экземпляр на приложение: muted-tap процесса + приватное агрегатное
/// устройство поверх текущего выхода. IOProc копирует сэмплы tap→выход,
/// умножая на атомарный gain, и публикует RMS-уровень для VU-метра.
public final class ProcessTapController: @unchecked Sendable {
    public let pid: pid_t

    private var tapID: AudioObjectID = .unknown
    private var aggregateID: AudioObjectID = .unknown
    private var ioProcID: AudioDeviceIOProcID?
    private let ioQueue: DispatchQueue
    private let gainBits: Atomic<UInt32>
    private let levelBits = Atomic<UInt32>(Float(0).bitPattern)
    private var invalidated = false

    public var level: Float { Float(bitPattern: levelBits.load(ordering: .relaxed)) }

    public func setGain(_ gain: Float) {
        gainBits.store(min(max(gain, 0), 1).bitPattern, ordering: .relaxed)
    }

    public init(app: AudioApp, initialGain: Float) throws {
        self.pid = app.id
        self.ioQueue = DispatchQueue(label: "mixer.io.\(app.id)", qos: .userInteractive)
        self.gainBits = Atomic<UInt32>(min(max(initialGain, 0), 1).bitPattern)

        // 1. Muted-tap: система глушит оригинальный вывод процесса, поток отдаёт нам
        let desc = CATapDescription(stereoMixdownOfProcesses: [NSNumber(value: app.objectID)])
        desc.name = "Микшер: \(app.name)"
        desc.muteBehavior = .mutedWhenTapped
        desc.isPrivate = true
        var tap = AudioObjectID.unknown
        try checkErr(AudioHardwareCreateProcessTap(desc, &tap), "create tap for \(app.name)")
        tapID = tap

        do {
            // 2. Приватный агрегат: текущее устройство вывода + наш tap
            let outputUID = try SystemVolume.defaultOutputDeviceUID()
            let description: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Микшер-\(app.id)",
                kAudioAggregateDeviceUIDKey: "ru.mikhail.VolumeMixer.agg.\(app.id).\(desc.uuid.uuidString)",
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [[
                    kAudioSubTapUIDKey: desc.uuid.uuidString,
                    kAudioSubTapDriftCompensationKey: true,
                ]],
            ]
            var agg = AudioObjectID.unknown
            try checkErr(AudioHardwareCreateAggregateDevice(description as CFDictionary, &agg), "create aggregate")
            aggregateID = agg

            // 3. IOProc: вход (tap) → выход, с gain и RMS
            let gainBits = self.gainBits
            let levelBits = self.levelBits
            var procID: AudioDeviceIOProcID?
            try checkErr(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, ioQueue) { _, inInputData, _, outOutputData, _ in
                let gain = Float(bitPattern: gainBits.load(ordering: .relaxed))
                let inABL = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInputData))
                let outABL = UnsafeMutableAudioBufferListPointer(outOutputData)
                var sumSquares: Float = 0
                var sampleCount = 0
                for i in 0..<min(inABL.count, outABL.count) {
                    let inBuf = inABL[i]
                    let outBuf = outABL[i]
                    guard let src = inBuf.mData?.assumingMemoryBound(to: Float32.self),
                          let dst = outBuf.mData?.assumingMemoryBound(to: Float32.self) else { continue }
                    let n = Int(min(inBuf.mDataByteSize, outBuf.mDataByteSize)) / MemoryLayout<Float32>.size
                    for j in 0..<n {
                        let s = src[j] * gain
                        dst[j] = s
                        sumSquares += s * s
                    }
                    sampleCount += n
                }
                let previous = Float(bitPattern: levelBits.load(ordering: .relaxed))
                let rms = sampleCount > 0 ? (sumSquares / Float(sampleCount)).squareRoot() : 0
                let smoothed = max(rms, previous * 0.85) // быстрая атака, плавный спад
                levelBits.store(smoothed.bitPattern, ordering: .relaxed)
            }, "create IOProc")
            ioProcID = procID

            try checkErr(AudioDeviceStart(aggregateID, ioProcID), "start device")
        } catch {
            invalidate()
            throw error
        }
    }

    public func invalidate() {
        guard !invalidated else { return }
        invalidated = true
        if let procID = ioProcID, aggregateID != .unknown {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        ioProcID = nil
        if aggregateID != .unknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = .unknown
        }
        if tapID != .unknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = .unknown
        }
    }

    deinit { invalidate() }
}
```

Примечание: `checkErr` с 3 аргументами тут не существует — сигнатура `checkErr(_:_:)`; вызов `AudioDeviceCreateIOProcIDWithBlock` оборачивается так: `let st = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, ioQueue, block); try checkErr(st, "create IOProc")`. При реализации разбить на две строки.

- [ ] **Step 2: `swift build`** → без ошибок
- [ ] **Step 3: Commit** `feat: контроллер tap'а с громкостью и VU`

---

### Task 8: AudioEngine + проверка разрешения

**Files:**
- Create: `Sources/VolumeMixerCore/AudioPermission.swift`
- Create: `Sources/VolumeMixerCore/AudioEngine.swift`

**Interfaces:**
- Consumes: всё из Task 3–7.
- Produces: `@MainActor AudioEngine: ObservableObject` — `@Published apps: [AudioApp]`, `@Published permissionGranted: Bool`, `func start()`, `func recheckPermission()`, `func setVolume(_:for:)`, `func setMuted(_:for:)`, `func volume(for:) -> Float`, `func isMuted(_:) -> Bool`, `func level(for:) -> Float`, `func hasController(for:) -> Bool`. `AudioPermission.preflight() -> Bool`.

- [ ] **Step 1: AudioPermission.swift**

```swift
import CoreAudio
import Foundation

public enum AudioPermission {
    /// Пробуем создать tap на первый попавшийся аудиопроцесс.
    /// Первый вызов показывает системный запрос на запись системного звука.
    /// Ошибка создания → разрешения нет.
    public static func preflight() -> Bool {
        guard let objectIDs = try? AudioObjectID.system.readObjectIDs(kAudioHardwarePropertyProcessObjectList),
              let first = objectIDs.first
        else { return true } // некого тапать — считаем, что ок, проверится на первом реальном tap'е

        let desc = CATapDescription(stereoMixdownOfProcesses: [NSNumber(value: first)])
        desc.name = "Микшер: проверка доступа"
        desc.muteBehavior = .unmuted
        desc.isPrivate = true
        var tap = AudioObjectID.unknown
        let status = AudioHardwareCreateProcessTap(desc, &tap)
        if tap != .unknown { AudioHardwareDestroyProcessTap(tap) }
        return status == noErr
    }

    /// Открыть настройки Конфиденциальность → Запись системного звука
    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!
}
```

- [ ] **Step 2: AudioEngine.swift**

```swift
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
        let diff = ProcessDiff.between(old: apps, new: newApps)
        for app in diff.removed {
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
```

- [ ] **Step 3: `swift build` && `swift test`** → PASS
- [ ] **Step 4: Commit** `feat: движок микшера и проверка разрешения`

---

### Task 9: UI — панель микшера

**Files:**
- Create: `Sources/VolumeMixerApp/MixerPanelView.swift`
- Create: `Sources/VolumeMixerApp/AppRowView.swift`
- Create: `Sources/VolumeMixerApp/OnboardingView.swift`
- Modify: `Sources/VolumeMixerApp/VolumeMixerApp.swift`

**Interfaces:**
- Consumes: `AudioEngine`, `SystemVolume`, `AudioPermission.settingsURL`, `VolumeCurve`.

- [ ] **Step 1: VolumeMixerApp.swift (замена целиком)**

```swift
import SwiftUI
import VolumeMixerCore

@main
struct VolumeMixerApp: App {
    @StateObject private var engine: AudioEngine

    init() {
        let e = AudioEngine()
        e.start()
        _engine = StateObject(wrappedValue: e)
    }

    var body: some Scene {
        MenuBarExtra("Микшер громкости", systemImage: "slider.vertical.3") {
            MixerPanelView()
                .environmentObject(engine)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 2: MixerPanelView.swift**

```swift
import SwiftUI
import VolumeMixerCore

struct MixerPanelView: View {
    @EnvironmentObject private var engine: AudioEngine
    @State private var masterVolume: Double = Double(SystemVolume.getVolume() ?? 0.5)
    @State private var editingMaster = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !engine.permissionGranted {
                OnboardingView()
            } else if engine.apps.isEmpty {
                Text("Сейчас ни одно приложение не воспроизводит звук")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(engine.apps) { app in
                    AppRowView(app: app)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
                Slider(value: $masterVolume, in: 0...1) { editing in
                    editingMaster = editing
                }
                .onChange(of: masterVolume) { _, v in
                    SystemVolume.setVolume(Float(v))
                }
                Text("\(Int(masterVolume * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            HStack {
                Text("Микшер громкости")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Выйти") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 320)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if !editingMaster, let v = SystemVolume.getVolume() {
                masterVolume = Double(v)
            }
        }
    }
}
```

- [ ] **Step 3: AppRowView.swift**

```swift
import SwiftUI
import VolumeMixerCore

struct AppRowView: View {
    @EnvironmentObject private var engine: AudioEngine
    let app: AudioApp

    @State private var slider: Double = 1
    @State private var level: Float = 0

    private let vuTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                }
                Text(app.name)
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
                if !engine.hasController(for: app) {
                    Text("нет доступа")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Button {
                        engine.setMuted(!engine.isMuted(app), for: app)
                    } label: {
                        Image(systemName: engine.isMuted(app) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundStyle(engine.isMuted(app) ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if engine.hasController(for: app) {
                HStack(spacing: 8) {
                    Slider(value: $slider, in: 0...1)
                        .onChange(of: slider) { _, v in
                            engine.setVolume(Float(v), for: app)
                        }
                        .disabled(engine.isMuted(app))
                    Text("\(Int(slider * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }

                // VU-метр: перцептивная шкала (sqrt), плавный спад — в контроллере
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule()
                            .fill(engine.isMuted(app) ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
                            .frame(width: geo.size.width * CGFloat(min(sqrt(level), 1)))
                    }
                }
                .frame(height: 3)
                .onReceive(vuTimer) { _ in
                    level = engine.level(for: app)
                }
            }
        }
        .opacity(engine.isMuted(app) ? 0.55 : 1)
        .onAppear { slider = Double(engine.volume(for: app)) }
    }
}
```

- [ ] **Step 4: OnboardingView.swift**

```swift
import SwiftUI
import VolumeMixerCore

struct OnboardingView: View {
    @EnvironmentObject private var engine: AudioEngine

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Нужен доступ к системному звуку")
                .font(.headline)
            Text("Чтобы регулировать громкость отдельных приложений, разрешите «Микшеру громкости» запись системного звука в настройках конфиденциальности.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Открыть настройки") {
                    NSWorkspace.shared.open(AudioPermission.settingsURL)
                }
                Button("Проверить снова") {
                    engine.recheckPermission()
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 5: `swift build` && `swift test`** → без ошибок, PASS
- [ ] **Step 6: Commit** `feat: панель микшера — строки приложений, VU, мастер-громкость, онбординг`

---

### Task 10: сквозная проверка + README

**Files:**
- Create: `README.md`

- [ ] **Step 1: собрать и запустить**

```bash
./build.sh && open "build/Микшер громкости.app"
```

- [ ] **Step 2: сквозной сценарий (руками, со звуком)**

1. Включить музыку (Spotify/Music/YouTube в браузере) — приложение появляется в панели, VU шевелится.
2. Двигать ползунок — громкость этого приложения меняется, остальные не трогает.
3. Mute — приложение замолкает, ползунок гаснет; unmute — возвращается.
4. Выставить громкость 30%, выйти из приложения микшера, запустить снова — 30% применились.
5. Переключить выход (наушники ↔ динамики) — звук и регулировка продолжают работать.
6. Диалог TCC при первом запуске; после «Запретить» панель показывает онбординг, после включения в настройках и «Проверить снова» — работает.

- [ ] **Step 3: README.md** — что это, скриншот-плейсхолдер, как собрать (`./build.sh`), требования (macOS 15+), как работает (process taps), ограничения v1.

- [ ] **Step 4: Commit** `docs: README` + финальный коммит.
