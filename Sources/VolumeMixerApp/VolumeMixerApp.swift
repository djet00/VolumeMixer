import SwiftUI
import Sparkle
import VolumeMixerCore

@main
struct VolumeMixerApp: App {
    @StateObject private var engine: AudioEngine

    // Sparkle: автопроверка обновлений по расписанию + ручная из панели
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    init() {
        let e = AudioEngine()
        e.start()
        _engine = StateObject(wrappedValue: e)
    }

    var body: some Scene {
        MenuBarExtra("Микшер громкости", systemImage: "slider.vertical.3") {
            MixerPanelView(updater: updaterController.updater)
                .environmentObject(engine)
        }
        .menuBarExtraStyle(.window)
    }
}
