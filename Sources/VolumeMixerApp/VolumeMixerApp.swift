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
