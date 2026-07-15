import SwiftUI
import VolumeMixerCore

struct OnboardingView: View {
    @EnvironmentObject private var engine: AudioEngine

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Нужен доступ к системному звуку")
                .font(.headline)
            Text("Чтобы регулировать громкость отдельных приложений, разрешите «Микшеру громкости» запись системного звука в настройках конфиденциальности.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Открыть настройки") {
                    NSWorkspace.shared.open(AudioPermission.settingsURL)
                }
                Button("Проверить снова") {
                    engine.recheckPermission()
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}
