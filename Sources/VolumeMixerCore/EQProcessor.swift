import Foundation
import Synchronization

/// Эквалайзер, безопасный для аудиопотока: каскад биквад-фильтров на канал.
///
/// Коэффициенты пишутся главным потоком в кольцо из четырёх слотов, активный
/// слот публикуется одним атомарным словом — в аудио-callback'е нет ни блокировок,
/// ни аллокаций, ни обращений к Swift-коллекциям.
public final class EQProcessor: @unchecked Sendable {
    /// Снимок состояния на один блок обработки.
    public struct Snapshot {
        let coefficients: UnsafePointer<BiquadCoefficients>?
        let bandCount: Int
        let preamp: Float

        public var isActive: Bool { coefficients != nil }
    }

    struct FilterState {
        var x1: Float = 0
        var x2: Float = 0
        var y1: Float = 0
        var y2: Float = 0
    }

    public static let maxChannels = 8
    private static let slotCount = 4
    private static let enabledBit: UInt32 = 0b100

    private let bandCount: Int
    private let coefficients: UnsafeMutablePointer<BiquadCoefficients>
    private let states: UnsafeMutablePointer<FilterState>
    private let control = Atomic<UInt32>(0)   // биты 0–1: слот, бит 2: включён
    private let preampBits = Atomic<UInt32>(Float(1).bitPattern)
    private var writeSlot = 0
    private var wasEnabled = false

    public init(bandCount: Int = EQSettings.bandCount) {
        self.bandCount = bandCount
        let coefficientCount = Self.slotCount * bandCount
        coefficients = .allocate(capacity: coefficientCount)
        coefficients.initialize(repeating: .identity, count: coefficientCount)
        let stateCount = Self.maxChannels * bandCount
        states = .allocate(capacity: stateCount)
        states.initialize(repeating: FilterState(), count: stateCount)
    }

    deinit {
        coefficients.deinitialize(count: Self.slotCount * bandCount)
        coefficients.deallocate()
        states.deinitialize(count: Self.maxChannels * bandCount)
        states.deallocate()
    }

    /// Главный поток: пересчитать коэффициенты и опубликовать их для аудиопотока.
    public func update(_ settings: EQSettings?, sampleRate: Double) {
        guard let settings, settings.enabled, sampleRate > 0 else {
            control.store(0, ordering: .releasing)
            wasEnabled = false
            return
        }
        // При включении сбрасываем память фильтров, иначе будет щелчок
        if !wasEnabled { resetStates() }
        wasEnabled = true

        writeSlot = (writeSlot + 1) % Self.slotCount
        let base = writeSlot * bandCount
        for band in 0..<bandCount {
            coefficients[base + band] = BiquadCoefficients.peaking(
                frequency: EQSettings.frequencies[band],
                gainDB: settings.gains[band],
                q: EQSettings.q,
                sampleRate: Float(sampleRate)
            )
        }
        preampBits.store(EQSettings.linearGain(fromDB: settings.preamp).bitPattern, ordering: .relaxed)
        control.store(UInt32(writeSlot) | Self.enabledBit, ordering: .releasing)
    }

    public func resetStates() {
        states.update(repeating: FilterState(), count: Self.maxChannels * bandCount)
    }

    /// Аудиопоток: снимок активных коэффициентов на текущий блок.
    @inline(__always)
    public func snapshot() -> Snapshot {
        let word = control.load(ordering: .acquiring)
        guard word & Self.enabledBit != 0 else {
            return Snapshot(coefficients: nil, bandCount: bandCount, preamp: 1)
        }
        let slot = Int(word & 0b11)
        return Snapshot(
            coefficients: UnsafePointer(coefficients.advanced(by: slot * bandCount)),
            bandCount: bandCount,
            preamp: Float(bitPattern: preampBits.load(ordering: .relaxed))
        )
    }

    /// Аудиопоток: обработать буфер на месте.
    /// `firstChannel` — глобальный номер первого канала буфера (буферов может быть несколько).
    @inline(__always)
    public func process(
        _ snapshot: Snapshot,
        buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channelsInBuffer: Int,
        firstChannel: Int
    ) {
        guard let coefficients = snapshot.coefficients, frameCount > 0, channelsInBuffer > 0 else { return }
        let bands = snapshot.bandCount
        let preamp = snapshot.preamp

        for channel in 0..<channelsInBuffer {
            let absoluteChannel = firstChannel + channel
            guard absoluteChannel < Self.maxChannels else { break }
            let state = states.advanced(by: absoluteChannel * bands)

            for frame in 0..<frameCount {
                let index = frame * channelsInBuffer + channel
                var sample = buffer[index] * preamp

                for band in 0..<bands {
                    let c = coefficients[band]
                    let s = state[band]
                    var output = c.b0 * sample + c.b1 * s.x1 + c.b2 * s.x2 - c.a1 * s.y1 - c.a2 * s.y2
                    // защита от денормалов и срывов фильтра
                    if !output.isFinite {
                        output = 0
                        state[band] = FilterState()
                        sample = output
                        continue
                    }
                    if abs(output) < 1e-20 { output = 0 }
                    state[band] = FilterState(x1: sample, x2: s.x1, y1: output, y2: s.y1)
                    sample = output
                }

                // подъём полос может вывести сигнал за пределы — ограничиваем
                buffer[index] = min(max(sample, -1), 1)
            }
        }
    }
}
