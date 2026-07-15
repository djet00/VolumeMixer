import CoreAudio
import Foundation

public enum AudioPermission {
    /// Пробуем создать tap на первый попавшийся аудиопроцесс.
    /// Первый вызов показывает системный запрос на запись системного звука.
    /// Ошибка создания → разрешения нет.
    public static func preflight() -> Bool {
        guard let objectIDs = try? AudioObjectID.system.readObjectIDs(kAudioHardwarePropertyProcessObjectList),
              let first = objectIDs.first
        else { return true } // некого тапать — проверится на первом реальном tap'е

        let desc = CATapDescription(stereoMixdownOfProcesses: [first])
        desc.name = "Микшер: проверка доступа"
        desc.muteBehavior = .unmuted
        desc.isPrivate = true
        var tap = AudioObjectID.unknown
        let status = AudioHardwareCreateProcessTap(desc, &tap)
        if tap != .unknown { AudioHardwareDestroyProcessTap(tap) }
        return status == noErr
    }

    /// Настройки → Конфиденциальность → Запись экрана и системного звука
    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!
}
