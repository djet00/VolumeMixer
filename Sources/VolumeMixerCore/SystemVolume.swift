import CoreAudio
import Foundation

public enum SystemVolume {
    /// 'vmvc' — виртуальная главная громкость (VirtualMainVolume).
    /// Селектор задан числом, чтобы не зависеть от имени константы в SDK.
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
        if dev.hasProperty(virtualMainVolume, scope: scope) {
            if (try? dev.writeFloat32(virtualMainVolume, scope: scope, value: v)) != nil {
                return
            }
        }
        for ch in [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)] {
            try? dev.writeFloat32(kAudioDevicePropertyVolumeScalar, scope: scope, element: ch, value: v)
        }
    }
}
