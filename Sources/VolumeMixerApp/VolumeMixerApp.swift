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
