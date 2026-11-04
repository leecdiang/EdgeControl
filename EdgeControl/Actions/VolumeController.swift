import CoreAudio
import Foundation

struct VolumeDeviceControl {
    let initialValue: Double
    let write: (Double) throws -> Void
}

protocol VolumeBackend: AnyObject {
    func currentOutputDevice() throws -> AudioDeviceID
    func readVolume(on device: AudioDeviceID) throws -> Double
    func writeVolume(_ value: Double, on device: AudioDeviceID) throws
    func prepareControl(on device: AudioDeviceID) throws -> VolumeDeviceControl
}

extension VolumeBackend {
    func prepareControl(on device: AudioDeviceID) throws -> VolumeDeviceControl {
        VolumeDeviceControl(initialValue: try readVolume(on: device), write: { [self] in
            try writeVolume($0, on: device)
        })
    }
}

final class VolumeControlSession {
    let initialValue: Double
    let pinnedDeviceID: AudioDeviceID
    private let write: (Double) throws -> Void
    private var lastWrittenValue: Float?

    init(backend: VolumeBackend) throws {
        pinnedDeviceID = try backend.currentOutputDevice()
        let control = try backend.prepareControl(on: pinnedDeviceID)
        guard control.initialValue.isFinite else {
            throw ControlError.readFailed("The audio device returned an invalid volume.")
        }
        initialValue = min(1, max(0, control.initialValue))
        write = control.write
    }

    func setVolume(_ value: Double) throws {
        guard value.isFinite else {
            throw ControlError.writeFailed("Volume must be a finite value.")
        }
        let target = Float(min(1, max(0, value)))
        guard target != lastWrittenValue else { return }
        try write(Double(target))
        lastWrittenValue = target
    }
}

protocol AudioVolumeTransport: AnyObject {
    func currentOutputDevice() throws -> AudioDeviceID
    func volumeElements(on device: AudioDeviceID, requireSettable: Bool) -> [AudioObjectPropertyElement]
    func readScalar(on device: AudioDeviceID, element: AudioObjectPropertyElement) throws -> Float
    func writeScalar(_ value: Float, on device: AudioDeviceID, element: AudioObjectPropertyElement) throws
}

/// Keep the original channel ratios even when a gesture passes through zero.
/// Peak scalar represents overall volume so 100% remains reachable without
/// clipping one channel and changing the balance. All-zero snapshots are neutral.
struct VolumeChannelSnapshot {
    let values: [Float]
    var initialValue: Double { Double(values.max() ?? 0) }

    init(values: [Float]) throws {
        guard !values.isEmpty, values.allSatisfy({ $0.isFinite }) else {
            throw ControlError.readFailed("The audio device returned an invalid channel volume.")
        }
        self.values = values.map { min(1, max(0, $0)) }
    }

    func targets(for value: Double) throws -> [Float] {
        guard value.isFinite else {
            throw ControlError.writeFailed("Volume must be a finite value.")
        }
        let target = Float(min(1, max(0, value)))
        let peak = values.max() ?? 0
        guard peak > 0 else { return values.map { _ in target } }
        return values.map { ($0 / peak) * target }
    }
}

final class VolumeController: VolumeBackend {
    private let transport: AudioVolumeTransport

    init(transport: AudioVolumeTransport = CoreAudioVolumeTransport()) {
        self.transport = transport
    }

    func currentOutputDevice() throws -> AudioDeviceID { try transport.currentOutputDevice() }
    func getVolume() throws -> Double { try readVolume(on: currentOutputDevice()) }
    func setVolume(_ value: Double) throws { try writeVolume(value, on: currentOutputDevice()) }
    func beginSession() throws -> VolumeControlSession { try VolumeControlSession(backend: self) }

    private func snapshot(on device: AudioDeviceID, elements: [AudioObjectPropertyElement]) throws -> VolumeChannelSnapshot {
        try VolumeChannelSnapshot(values: elements.map { try transport.readScalar(on: device, element: $0) })
    }

    func readVolume(on device: AudioDeviceID) throws -> Double {
        let elements = transport.volumeElements(on: device, requireSettable: false)
        return try snapshot(on: device, elements: elements).initialValue
    }

    func writeVolume(_ value: Double, on device: AudioDeviceID) throws {
        guard value.isFinite else { throw ControlError.writeFailed("Volume must be a finite value.") }
        try prepareControl(on: device).write(value)
    }

    func prepareControl(on device: AudioDeviceID) throws -> VolumeDeviceControl {
        let elements = transport.volumeElements(on: device, requireSettable: true)
        guard !elements.isEmpty else {
            throw ControlError.unavailable("This output does not expose software volume control.")
        }
        let original = try snapshot(on: device, elements: elements)
        return VolumeDeviceControl(initialValue: original.initialValue, write: { [self] value in
            let targets = try original.targets(for: value)
            guard transport.volumeElements(on: device, requireSettable: true) == elements else {
                throw ControlError.unavailable("The audio device's volume controls changed. Start a new gesture.")
            }
            // Validate every channel before the first write; never average a
            // partially successful read. Retain current values for rollback.
            let previous = try snapshot(on: device, elements: elements).values
            var attempted: [Int] = []
            do {
                for index in elements.indices {
                    attempted.append(index)
                    try transport.writeScalar(targets[index], on: device, element: elements[index])
                }
            } catch {
                var restored = true
                for index in attempted.reversed() {
                    do { try transport.writeScalar(previous[index], on: device, element: elements[index]) }
                    catch { restored = false }
                }
                if !restored {
                    throw ControlError.writeFailed("Volume change failed and channel restoration was incomplete.")
                }
                throw error
            }
        })
    }
}

final class CoreAudioVolumeTransport: AudioVolumeTransport {
    func readScalar(on device: AudioDeviceID, element: AudioObjectPropertyElement) throws -> Float {
        guard let value = readFloatProperty(selector: kAudioDevicePropertyVolumeScalar, device: device, element: element),
              value.isFinite else {
            throw ControlError.readFailed("The audio channel volume could not be read or was invalid.")
        }
        return value
    }

    func writeScalar(_ value: Float, on device: AudioDeviceID, element: AudioObjectPropertyElement) throws {
        guard value.isFinite else { throw ControlError.writeFailed("Volume must be finite.") }
        var scalar = min(1, max(0, value))
        var address = propertyAddress(selector: kAudioDevicePropertyVolumeScalar, element: element)
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float>.size), &scalar)
        guard status == noErr else {
            throw ControlError.writeFailed("The output volume could not be changed (CoreAudio \(status)).")
        }
    }

    func isMuted() throws -> Bool {
        let device = try currentOutputDevice()
        for element in candidateElements(on: device) {
            if let value = readUInt32Property(
                selector: kAudioDevicePropertyMute,
                device: device,
                element: element
            ) {
                return value != 0
            }
        }
        return false
    }

    func setMuted(_ muted: Bool) throws {
        let device = try currentOutputDevice()
        var wroteAtLeastOne = false
        for element in candidateElements(on: device) {
            var address = propertyAddress(selector: kAudioDevicePropertyMute, element: element)
            guard AudioObjectHasProperty(device, &address), isSettable(device: device, address: &address) else {
                continue
            }
            var value: UInt32 = muted ? 1 : 0
            let status = AudioObjectSetPropertyData(
                device,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<UInt32>.size),
                &value
            )
            guard status == noErr else {
                throw ControlError.writeFailed("Mute could not be changed (CoreAudio \(status)).")
            }
            wroteAtLeastOne = true
        }
        guard wroteAtLeastOne else {
            throw ControlError.unavailable("Mute is unavailable for the current output device.")
        }
    }

    func isCurrentOutputVolumeSettable() -> Bool {
        guard let device = try? currentOutputDevice() else { return false }
        return !volumeElements(on: device, requireSettable: true).isEmpty
    }

    func currentOutputDevice() throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &device
        )
        guard status == noErr, device != kAudioObjectUnknown else {
            throw ControlError.unavailable("No default audio output device is available.")
        }
        return device
    }

    func volumeElements(on device: AudioDeviceID, requireSettable: Bool) -> [AudioObjectPropertyElement] {
        var master = propertyAddress(selector: kAudioDevicePropertyVolumeScalar, element: kAudioObjectPropertyElementMain)
        if AudioObjectHasProperty(device, &master) && (!requireSettable || isSettable(device: device, address: &master)) {
            return [kAudioObjectPropertyElementMain]
        }

        return [1, 2].filter { element in
            var address = propertyAddress(selector: kAudioDevicePropertyVolumeScalar, element: element)
            return AudioObjectHasProperty(device, &address) && (!requireSettable || isSettable(device: device, address: &address))
        }
    }

    private func candidateElements(on device: AudioDeviceID) -> [AudioObjectPropertyElement] {
        [kAudioObjectPropertyElementMain, 1, 2]
    }

    private func propertyAddress(
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private func isSettable(
        device: AudioDeviceID,
        address: inout AudioObjectPropertyAddress
    ) -> Bool {
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    private func readFloatProperty(
        selector: AudioObjectPropertySelector,
        device: AudioDeviceID,
        element: AudioObjectPropertyElement
    ) -> Float? {
        var address = propertyAddress(selector: selector, element: element)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: Float = 0
        var size = UInt32(MemoryLayout<Float>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr,
              size == UInt32(MemoryLayout.size(ofValue: value)) else {
            return nil
        }
        return value
    }

    private func readUInt32Property(
        selector: AudioObjectPropertySelector,
        device: AudioDeviceID,
        element: AudioObjectPropertyElement
    ) -> UInt32? {
        var address = propertyAddress(selector: selector, element: element)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr,
              size == UInt32(MemoryLayout.size(ofValue: value)) else {
            return nil
        }
        return value
    }
}
