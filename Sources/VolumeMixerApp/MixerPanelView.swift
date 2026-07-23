import SwiftUI
import Sparkle
import VolumeMixerCore

struct MixerPanelView: View {
    let updater: SPUUpdater

    @EnvironmentObject private var engine: AudioEngine
    @State private var masterVolume: Double = Double(SystemVolume.getVolume() ?? 0.5)
    @State private var editingMaster = false
    @State private var panelOpen = false

    private let layoutTimer = Timer.publish(
        every: 1.0 / 30.0,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !engine.permissionGranted {
                OnboardingView()
            } else if engine.sections.pinned.isEmpty
                        && engine.sections.playing.isEmpty
                        && engine.sections.silent.isEmpty
            {
                Text("Приложений со звуком пока нет")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                if !engine.sections.pinned.isEmpty {
                    sectionHeader("Закреплённые")
                    ForEach(engine.sections.pinned) { item in
                        switch item {
                        case .live(let app):
                            AppRowView(app: app, isPinned: true)
                        case .ghost(let bundleID, let name):
                            GhostAppRowView(bundleID: bundleID, name: name)
                        }
                    }
                }
                if !engine.sections.playing.isEmpty {
                    sectionHeader("Сейчас играют")
                    ForEach(engine.sections.playing) { app in
                        AppRowView(app: app, isPinned: false)
                    }
                }
                if !engine.sections.silent.isEmpty {
                    sectionHeader("Молчат")
                    ForEach(engine.sections.silent) { app in
                        AppRowView(app: app, isPinned: false)
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
                Button("Обновления") { updater.checkForUpdates() }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
        .onAppear {
            panelOpen = true
            engine.relayout()
        }
        .onDisappear { panelOpen = false }
        .onReceive(layoutTimer) { _ in
            if panelOpen {
                engine.relayout()
            }
        }
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
