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
