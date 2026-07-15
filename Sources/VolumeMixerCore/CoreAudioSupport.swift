import CoreAudio
import Foundation

enum CoreAudioError: Error, CustomStringConvertible {
    case osStatus(OSStatus, String)
    var description: String {
        if case let .osStatus(s, what) = self { return "CoreAudio: \(what) → \(s)" }
        return "CoreAudio error"
    }
}

func checkErr(_ status: OSStatus, _ what: String) throws {
    guard status == noErr else { throw CoreAudioError.osStatus(status, what) }
}

func propertyAddress(_ selector: AudioObjectPropertySelector,
                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                     element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
}

extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)
    static let unknown = AudioObjectID(kAudioObjectUnknown)

    func readUInt32(_ selector: AudioObjectPropertySelector,
                    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> UInt32 {
        var addr = propertyAddress(selector, scope: scope)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try checkErr(AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value), "read \(selector)")
        return value
    }

    func readInt32(_ selector: AudioObjectPropertySelector) throws -> Int32 {
        var addr = propertyAddress(selector)
        var value: Int32 = 0
        var size = UInt32(MemoryLayout<Int32>.size)
        try checkErr(AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value), "read \(selector)")
        return value
    }

    func readObjectID(_ selector: AudioObjectPropertySelector) throws -> AudioObjectID {
        try AudioObjectID(readUInt32(selector))
    }

    func readString(_ selector: AudioObjectPropertySelector) throws -> String {
        var addr = propertyAddress(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try checkErr(AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value), "read \(selector)")
        return value?.takeRetainedValue() as String? ?? ""
    }

    func readObjectIDs(_ selector: AudioObjectPropertySelector) throws -> [AudioObjectID] {
        var addr = propertyAddress(selector)
        var size: UInt32 = 0
        try checkErr(AudioObjectGetPropertyDataSize(self, &addr, 0, nil, &size), "size \(selector)")
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        guard count > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: count)
        try checkErr(AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &ids), "read \(selector)")
        return ids
    }

    func readFloat32(_ selector: AudioObjectPropertySelector,
                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                     element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) throws -> Float32 {
        var addr = propertyAddress(selector, scope: scope, element: element)
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        try checkErr(AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value), "read \(selector)")
        return value
    }

    func writeFloat32(_ selector: AudioObjectPropertySelector,
                      scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                      element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
                      value: Float32) throws {
        var addr = propertyAddress(selector, scope: scope, element: element)
        var v = value
        try checkErr(AudioObjectSetPropertyData(self, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v), "write \(selector)")
    }

    func hasProperty(_ selector: AudioObjectPropertySelector,
                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                     element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> Bool {
        var addr = propertyAddress(selector, scope: scope, element: element)
        return AudioObjectHasProperty(self, &addr)
    }
}

/// RAII-подписка на изменение свойства CoreAudio-объекта.
final class PropertyListener {
    private let objectID: AudioObjectID
    private var address: AudioObjectPropertyAddress
    private let queue: DispatchQueue
    private let block: AudioObjectPropertyListenerBlock

    init?(objectID: AudioObjectID,
          selector: AudioObjectPropertySelector,
          scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
          queue: DispatchQueue = .main,
          handler: @escaping () -> Void) {
        self.objectID = objectID
        self.address = propertyAddress(selector, scope: scope)
        self.queue = queue
        self.block = { _, _ in handler() }
        guard AudioObjectAddPropertyListenerBlock(objectID, &address, queue, block) == noErr else { return nil }
    }

    deinit {
        AudioObjectRemovePropertyListenerBlock(objectID, &address, queue, block)
    }
}
