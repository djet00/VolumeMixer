import SwiftUI
import VolumeMixerCore

/// Вертикальный ползунок одной полосы эквалайзера.
struct EQBandSlider: View {
    @Binding var value: Float
    let height: CGFloat

    private let knob: CGFloat = 12
    private let range = EQSettings.range

    var body: some View {
        GeometryReader { geo in
            let usable = max(geo.size.height - knob, 1)
            let position = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))

            ZStack(alignment: .top) {
                Capsule()
                    .fill(.quaternary)
                    .frame(width: 2)
                    .frame(maxWidth: .infinity)
                Rectangle()                       // отметка нуля
                    .fill(.tertiary)
                    .frame(width: 10, height: 1)
                    .offset(y: usable / 2 + knob / 2)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: knob, height: knob)
                    .offset(y: usable * (1 - position))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { drag in
                        let y = min(max(drag.location.y - knob / 2, 0), usable)
                        let fraction = Float(1 - y / usable)
                        value = EQSettings.clamp(range.lowerBound + fraction * (range.upperBound - range.lowerBound))
                    }
            )
            .onTapGesture(count: 2) { value = 0 }   // двойной клик — сброс полосы
        }
        .frame(width: 20, height: height)
    }
}

/// Панель эквалайзера: 10 полос, общий уровень, пресеты.
/// Используется и для приложения, и для общего эквалайзера.
struct EqualizerView: View {
    let toggleLabel: String
    let footnote: (Bool) -> String
    let initial: EQSettings
    let onChange: (EQSettings) -> Void

    @State private var settings = EQSettings()
    @State private var presetID = EQSettings.customPresetID

    private let sliderHeight: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Toggle(toggleLabel, isOn: Binding(
                    get: { settings.enabled },
                    set: { settings.enabled = $0; push() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.caption)
                Spacer()
                Button("Сбросить") {
                    settings = EQSettings(enabled: settings.enabled)
                    presetID = "flat"
                    push()
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .disabled(settings.isFlat)
            }

            Text(footnote(settings.enabled))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            bands
                .disabled(!settings.enabled)
                .opacity(settings.enabled ? 1 : 0.4)

            Picker("", selection: Binding(
                get: { presetID },
                set: { applyPreset($0) }
            )) {
                if presetID == EQSettings.customPresetID {
                    Text("Свои настройки").tag(EQSettings.customPresetID)
                }
                ForEach(EQSettings.presets) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .disabled(!settings.enabled)
        }
        .padding(.vertical, 4)
        .onAppear {
            settings = initial
            presetID = EQSettings.presetID(matching: initial.gains) ?? EQSettings.customPresetID
        }
    }

    private var bands: some View {
        HStack(alignment: .top, spacing: 3) {
            VStack(alignment: .trailing, spacing: 0) {   // шкала дБ
                Text("+12")
                Spacer()
                Text("0")
                Spacer()
                Text("−12")
            }
            .font(.system(size: 7))
            .foregroundStyle(.tertiary)
            .frame(height: sliderHeight)
            .padding(.trailing, 1)

            band(label: "ур.", value: Binding(
                get: { settings.preamp },
                set: { settings.preamp = $0; push() }
            ))

            Divider().frame(height: sliderHeight)

            ForEach(Array(EQSettings.frequencyLabels.enumerated()), id: \.offset) { index, label in
                band(label: label, value: Binding(
                    get: { settings.gains[index] },
                    set: { newValue in
                        settings.gains[index] = newValue
                        presetID = EQSettings.presetID(matching: settings.gains) ?? EQSettings.customPresetID
                        push()
                    }
                ))
            }
        }
    }

    private func band(label: String, value: Binding<Float>) -> some View {
        VStack(spacing: 3) {
            EQBandSlider(value: value, height: sliderHeight)
            Text(label)
                .font(.system(size: 7.5))
                .foregroundStyle(.secondary)
        }
    }

    private func applyPreset(_ id: String) {
        guard let preset = EQSettings.presets.first(where: { $0.id == id }) else { return }
        settings.gains = preset.gains
        presetID = id
        push()
    }

    private func push() {
        onChange(settings)
    }
}

/// Значок «EQ» у строки приложения и в подвале панели.
struct EQBadge: View {
    let activation: EQActivation

    var body: some View {
        Text("EQ")
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(activation == .own ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(activation == .global ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary), lineWidth: 1)
                    .opacity(activation == .own ? 0 : 1)
            )
    }

    private var foreground: some ShapeStyle {
        switch activation {
        case .own: AnyShapeStyle(.white)
        case .global: AnyShapeStyle(.tint)
        case .off: AnyShapeStyle(.tertiary)
        }
    }
}
