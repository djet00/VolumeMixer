import CoreAudio
import Foundation
import Synchronization

/// Один экземпляр на приложение: muted-tap процесса + приватное агрегатное
/// устройство поверх текущего выхода. IOProc копирует сэмплы tap→выход,
/// умножая на атомарный gain, и публикует RMS-уровень для VU-метра.
public final class ProcessTapController: @unchecked Sendable {
    /// Атомики в отдельной коробке: её ссылку захватывает IO-блок,
    /// не удерживая сам контроллер (deinit контроллера остаётся рабочим).
    private final class MixState: @unchecked Sendable {
        let gainBits: Atomic<UInt32>
        let levelBits = Atomic<UInt32>(Float(0).bitPattern)
        init(gain: Float) { gainBits = Atomic<UInt32>(gain.bitPattern) }
    }

    public let pid: pid_t

    private var tapID: AudioObjectID = .unknown
    private var aggregateID: AudioObjectID = .unknown
    private var ioProcID: AudioDeviceIOProcID?
    private let ioQueue: DispatchQueue
    private let state: MixState
    private var invalidated = false

    public var level: Float { Float(bitPattern: state.levelBits.load(ordering: .relaxed)) }

    public func setGain(_ gain: Float) {
        state.gainBits.store(min(max(gain, 0), 1).bitPattern, ordering: .relaxed)
    }

    public init(process proc: AudioProcess, initialGain: Float) throws {
        self.pid = proc.pid
        self.ioQueue = DispatchQueue(label: "mixer.io.\(proc.pid)", qos: .userInteractive)
        self.state = MixState(gain: min(max(initialGain, 0), 1))

        // 1. Muted-tap: система глушит оригинальный вывод процесса, поток отдаёт нам
        let desc = CATapDescription(stereoMixdownOfProcesses: [proc.objectID])
        desc.name = "Микшер: \(proc.name)"
        desc.muteBehavior = .mutedWhenTapped
        desc.isPrivate = true
        var tap = AudioObjectID.unknown
        try checkErr(AudioHardwareCreateProcessTap(desc, &tap), "create tap for \(proc.name)")
        tapID = tap

        do {
            // 2. Приватный агрегат: текущее устройство вывода + наш tap
            let outputUID = try SystemVolume.defaultOutputDeviceUID()
            let description: [String: Any] = [
                kAudioAggregateDeviceNameKey: "Микшер-\(proc.pid)",
                kAudioAggregateDeviceUIDKey: "ru.mikhail.VolumeMixer.agg.\(proc.pid).\(desc.uuid.uuidString)",
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [[
                    kAudioSubTapUIDKey: desc.uuid.uuidString,
                    kAudioSubTapDriftCompensationKey: true,
                ]],
            ]
            var agg = AudioObjectID.unknown
            try checkErr(AudioHardwareCreateAggregateDevice(description as CFDictionary, &agg), "create aggregate")
            aggregateID = agg

            // 3. IOProc: вход (tap) → выход, с gain и RMS
            let state = self.state
            var procID: AudioDeviceIOProcID?
            let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, ioQueue) { _, inInputData, _, outOutputData, _ in
                let gain = Float(bitPattern: state.gainBits.load(ordering: .relaxed))
                let inABL = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInputData))
                let outABL = UnsafeMutableAudioBufferListPointer(outOutputData)
                var sumSquares: Float = 0
                var sampleCount = 0
                for i in 0..<min(inABL.count, outABL.count) {
                    let inBuf = inABL[i]
                    let outBuf = outABL[i]
                    guard let src = inBuf.mData?.assumingMemoryBound(to: Float32.self),
                          let dst = outBuf.mData?.assumingMemoryBound(to: Float32.self) else { continue }
                    let n = Int(min(inBuf.mDataByteSize, outBuf.mDataByteSize)) / MemoryLayout<Float32>.size
                    for j in 0..<n {
                        let s = src[j] * gain
                        dst[j] = s
                        sumSquares += s * s
                    }
                    sampleCount += n
                }
                let previous = Float(bitPattern: state.levelBits.load(ordering: .relaxed))
                let rms = sampleCount > 0 ? (sumSquares / Float(sampleCount)).squareRoot() : 0
                let smoothed = max(rms, previous * 0.85) // быстрая атака, плавный спад
                state.levelBits.store(smoothed.bitPattern, ordering: .relaxed)
            }
            try checkErr(status, "create IOProc")
            ioProcID = procID

            try checkErr(AudioDeviceStart(aggregateID, ioProcID), "start device")
        } catch {
            invalidate()
            throw error
        }
    }

    public func invalidate() {
        guard !invalidated else { return }
        invalidated = true
        if let procID = ioProcID, aggregateID != .unknown {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        ioProcID = nil
        if aggregateID != .unknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = .unknown
        }
        if tapID != .unknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = .unknown
        }
    }

    deinit { invalidate() }
}
