import SwiftUI
import VolumeMixerCore

struct MixerPanelView: View {
    @EnvironmentObject private var engine: AudioEngine
    @State private var masterVolume: Double = Double(SystemVolume.getVolume() ?? 0.5)
    @State private var editingMaster = false

    private var playing: [AudioApp] { engine.apps.filter(\.isPlaying) }
    private var silent: [AudioApp] { engine.apps.filter { !$0.isPlaying } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !engine.permissionGranted {
                OnboardingView()
            } else if engine.apps.isEmpty {
                Text("Приложений со звуком пока нет")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                if !playing.isEmpty {
                    sectionHeader("Сейчас играют")
                    ForEach(playing) { app in
                        AppRowView(app: app)
                    }
                }
                if !silent.isEmpty {
                    sectionHeader("Молчат")
                    ForEach(silent) { app in
                        AppRowView(app: app)
                    }
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

            HStack(spacing: 12) {
                Text("Микшер громкости \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Обратная связь") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/djet00/VolumeMixer/issues/new/choose")!)
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.secondary)
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
    }
}
