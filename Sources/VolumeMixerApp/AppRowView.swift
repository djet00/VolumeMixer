import SwiftUI
import VolumeMixerCore

struct AppRowView: View {
    @EnvironmentObject private var engine: AudioEngine
    let app: AudioApp
    let isPinned: Bool

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
                        .saturation(app.isPlaying ? 1 : 0.4)
                }
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                Text(app.name)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(app.isPlaying ? .primary : .secondary)
                    .accessibilityLabel(isPinned ? "\(app.name), закреплено" : app.name)
                Spacer()
                if engine.tapFailed(for: app) {
                    Text("нет доступа")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Button {
                        engine.setMuted(!engine.isMuted(app), for: app)
                    } label: {
                        Image(systemName: engine.isMuted(app) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundStyle(engine.isMuted(app) ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !engine.tapFailed(for: app) {
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

                if app.isPlaying {
                    // VU-метр: перцептивная шкала (sqrt), сглаживание — в контроллере
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
        }
        .opacity(engine.isMuted(app) ? 0.55 : 1)
        .onAppear { slider = Double(engine.volume(for: app)) }
        .contentShape(Rectangle())
        .contextMenu { pinMenu(includeLimitDisabled: true) }
        .accessibilityActions { pinMenu(includeLimitDisabled: false) }
    }

    @ViewBuilder
    private func pinMenu(includeLimitDisabled: Bool) -> some View {
        if isPinned {
            Button("Открепить") { engine.unpin(bundleID: app.bundleID) }
            Button("Переместить выше") { engine.movePinned(bundleID: app.bundleID, direction: .up) }
            Button("Переместить ниже") { engine.movePinned(bundleID: app.bundleID, direction: .down) }
        } else if engine.canPin(app) {
            Button("Закрепить") { _ = engine.pin(app) }
        } else if includeLimitDisabled {
            Button("Закрепить — максимум 6") {}.disabled(true)
        }
    }
}
