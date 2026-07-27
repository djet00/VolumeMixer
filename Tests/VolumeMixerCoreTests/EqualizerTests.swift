import Testing
import Foundation
@testable import VolumeMixerCore

@Suite struct EqualizerSettingsTests {
    @Test func defaultsAreFlatAndOff() {
        let eq = EQSettings()
        #expect(eq.enabled == false)
        #expect(eq.preamp == 0)
        #expect(eq.gains.count == EQSettings.bandCount)
        #expect(eq.isFlat)
    }

    @Test func clampsOutOfRangeValues() {
        let eq = EQSettings(enabled: true, preamp: 99, gains: [50, -50, 0, 0, 0, 0, 0, 0, 0, 0])
        #expect(eq.preamp == 12)
        #expect(eq.gains[0] == 12)
        #expect(eq.gains[1] == -12)
    }

    @Test func normalizesWrongBandCount() {
        #expect(EQSettings(gains: [1, 2, 3]).gains.count == EQSettings.bandCount)
        #expect(EQSettings(gains: [Float](repeating: 1, count: 30)).gains.count == EQSettings.bandCount)
        #expect(EQSettings(gains: [1, 2, 3]).gains[5] == 0)
    }

    @Test func survivesBrokenStoredData() throws {
        let json = Data(#"{"enabled":true}"#.utf8)
        let eq = try JSONDecoder().decode(EQSettings.self, from: json)
        #expect(eq.enabled == true)
        #expect(eq.gains.count == EQSettings.bandCount)
    }

    @Test func roundTripsThroughJSON() throws {
        let original = EQSettings(enabled: true, preamp: -3, gains: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        let decoded = try JSONDecoder().decode(EQSettings.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func presetsHaveCorrectShape() {
        #expect(EQSettings.presets.count >= 5)
        for preset in EQSettings.presets {
            #expect(preset.gains.count == EQSettings.bandCount)
            #expect(preset.gains.allSatisfy { EQSettings.range.contains($0) })
        }
    }

    @Test func recognizesPresetAndCustomGains() {
        #expect(EQSettings.presetID(matching: EQSettings.flatGains) == "flat")
        let rock = EQSettings.presets.first { $0.id == "rock" }!
        #expect(EQSettings.presetID(matching: rock.gains) == "rock")
        #expect(EQSettings.presetID(matching: [11, -11, 0, 0, 0, 0, 0, 0, 0, 0]) == nil)
    }

    @Test func decibelsToLinearGain() {
        #expect(abs(EQSettings.linearGain(fromDB: 0) - 1) < 0.0001)
        #expect(abs(EQSettings.linearGain(fromDB: 6) - 1.9953) < 0.001)
        #expect(abs(EQSettings.linearGain(fromDB: -6) - 0.5012) < 0.001)
    }
}

@Suite struct BiquadTests {
    private let sampleRate: Float = 48_000

    @Test func zeroGainIsTransparent() {
        let c = BiquadCoefficients.peaking(frequency: 1_000, gainDB: 0, q: EQSettings.q, sampleRate: sampleRate)
        #expect(c == .identity)
    }

    @Test func boostGivesRequestedGainAtCenterFrequency() {
        for gain: Float in [3, 6, 12] {
            let c = BiquadCoefficients.peaking(frequency: 1_000, gainDB: gain, q: EQSettings.q, sampleRate: sampleRate)
            let magnitudeDB = 20 * log10(c.magnitude(at: 1_000, sampleRate: sampleRate))
            #expect(abs(magnitudeDB - gain) < 0.15)
        }
    }

    @Test func cutGivesRequestedAttenuation() {
        let c = BiquadCoefficients.peaking(frequency: 3_000, gainDB: -9, q: EQSettings.q, sampleRate: sampleRate)
        let magnitudeDB = 20 * log10(c.magnitude(at: 3_000, sampleRate: sampleRate))
        #expect(abs(magnitudeDB + 9) < 0.15)
    }

    @Test func farFromCenterStaysNeutral() {
        let c = BiquadCoefficients.peaking(frequency: 60, gainDB: 12, q: EQSettings.q, sampleRate: sampleRate)
        let magnitudeDB = 20 * log10(c.magnitude(at: 8_000, sampleRate: sampleRate))
        #expect(abs(magnitudeDB) < 0.5)
    }

    @Test func rejectsImpossibleParameters() {
        #expect(BiquadCoefficients.peaking(frequency: 30_000, gainDB: 6, q: 1.41, sampleRate: 48_000) == .identity)
        #expect(BiquadCoefficients.peaking(frequency: 1_000, gainDB: 6, q: 1.41, sampleRate: 0) == .identity)
        #expect(BiquadCoefficients.peaking(frequency: 0, gainDB: 6, q: 1.41, sampleRate: 48_000) == .identity)
    }

    @Test func filterIsStableOnLoudSignal() {
        // прогоняем шум через каскад на максимальном подъёме — сигнал не должен разойтись
        let processor = EQProcessor()
        processor.update(
            EQSettings(enabled: true, preamp: 12, gains: [Float](repeating: 12, count: EQSettings.bandCount)),
            sampleRate: 48_000
        )
        let snapshot = processor.snapshot()
        #expect(snapshot.isActive)

        let frames = 4_096
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { buffer.deallocate() }
        var seed: UInt64 = 12_345
        for i in 0..<(frames * 2) {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            buffer[i] = Float(Int32(truncatingIfNeeded: seed >> 33)) / Float(Int32.max)
        }
        processor.process(snapshot, buffer: buffer, frameCount: frames, channelsInBuffer: 2, firstChannel: 0)

        for i in 0..<(frames * 2) {
            #expect(buffer[i].isFinite)
            #expect(abs(buffer[i]) <= 1.0001)
        }
    }

    @Test func disabledProcessorLeavesSamplesUntouched() {
        let processor = EQProcessor()
        processor.update(nil, sampleRate: 48_000)
        let snapshot = processor.snapshot()
        #expect(!snapshot.isActive)

        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: 4)
        defer { buffer.deallocate() }
        for i in 0..<4 { buffer[i] = 0.5 }
        processor.process(snapshot, buffer: buffer, frameCount: 2, channelsInBuffer: 2, firstChannel: 0)
        for i in 0..<4 { #expect(buffer[i] == 0.5) }
    }

    @Test func flatEnabledEQPassesSignalThrough() {
        let processor = EQProcessor()
        processor.update(EQSettings(enabled: true), sampleRate: 48_000)
        let snapshot = processor.snapshot()

        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: 8)
        defer { buffer.deallocate() }
        for i in 0..<8 { buffer[i] = 0.25 }
        processor.process(snapshot, buffer: buffer, frameCount: 4, channelsInBuffer: 2, firstChannel: 0)
        for i in 0..<8 { #expect(abs(buffer[i] - 0.25) < 0.0001) }
    }
}

@Suite struct EQResolutionTests {
    private let ownEQ = EQSettings(enabled: true, preamp: 3, gains: [6, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    private let globalEQ = EQSettings(enabled: true, preamp: -3, gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 6])

    @Test func ownEQWinsOverGlobal() {
        #expect(EQResolution.effective(app: ownEQ, global: globalEQ) == ownEQ)
        #expect(EQResolution.activation(app: ownEQ, global: globalEQ) == .own)
    }

    @Test func globalAppliesWhenAppHasNone() {
        let appOff = EQSettings(enabled: false, gains: [9, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        #expect(EQResolution.effective(app: appOff, global: globalEQ) == globalEQ)
        #expect(EQResolution.activation(app: appOff, global: globalEQ) == .global)
    }

    @Test func nothingAppliesWhenBothOff() {
        let off = EQSettings(enabled: false)
        #expect(EQResolution.effective(app: off, global: off) == nil)
        #expect(EQResolution.activation(app: off, global: off) == .off)
    }

    @Test func ownEQWorksEvenWithGlobalOff() {
        let off = EQSettings(enabled: false)
        #expect(EQResolution.effective(app: ownEQ, global: off) == ownEQ)
    }
}

@Suite struct SettingsStoreEQTests {
    private func freshDefaults() -> UserDefaults {
        let name = "eq-test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func globalEQDefaultsToOff() {
        #expect(SettingsStore(defaults: freshDefaults()).globalEQ.enabled == false)
    }

    @Test func globalEQPersists() {
        let d = freshDefaults()
        let store = SettingsStore(defaults: d)
        store.globalEQ = EQSettings(enabled: true, preamp: 2, gains: [4, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        let restored = SettingsStore(defaults: d).globalEQ
        #expect(restored.enabled)
        #expect(abs(restored.gains[0] - 4) < 0.0001)
    }

    @Test func appEQPersistsAndIsIndependent() {
        let d = freshDefaults()
        let store = SettingsStore(defaults: d)
        store.setEQ(EQSettings(enabled: true, gains: [8, 0, 0, 0, 0, 0, 0, 0, 0, 0]), for: "com.spotify.client")
        let restored = SettingsStore(defaults: d)
        #expect(restored.eq(for: "com.spotify.client").enabled)
        #expect(restored.eq(for: "com.apple.Safari").enabled == false)
        #expect(restored.eq(for: "com.apple.Safari").isFlat)
    }

    @Test func emptyOffEQIsNotStored() {
        let d = freshDefaults()
        let store = SettingsStore(defaults: d)
        store.setEQ(EQSettings(enabled: true, gains: [5, 0, 0, 0, 0, 0, 0, 0, 0, 0]), for: "a")
        store.setEQ(EQSettings(), for: "a")
        #expect(SettingsStore(defaults: d).eq(for: "a").isFlat)
    }

    @Test func disabledButTunedEQKeepsItsGains() {
        let d = freshDefaults()
        SettingsStore(defaults: d).setEQ(EQSettings(enabled: false, gains: [7, 0, 0, 0, 0, 0, 0, 0, 0, 0]), for: "b")
        let restored = SettingsStore(defaults: d).eq(for: "b")
        #expect(restored.enabled == false)
        #expect(abs(restored.gains[0] - 7) < 0.0001)
    }
}
