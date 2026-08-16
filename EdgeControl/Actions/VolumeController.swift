import CoreAudio
import Foundation

final class VolumeController {
    func getVolume() throws -> Double {
        let device = try currentOutputDevice()
        let elements = volumeElements(on: device, requireSettable: false)
        guard !elements.isEmpty else {
            throw ControlError.unavailable("Volume is unavailable for the current output device.")
        }

        let values = elements.compactMap { readFloatProperty(
            selector: kAudioDevicePropertyVolumeScalar,
            device: device,
            element: $0
        ) }
        guard !values.isEmpty else {
            throw ControlError.readFailed("The current output volume could not be read.")
        }
        return Double(values.reduce(0, +) / Float(values.count))
    }

    func setVolume(_ value: Double) throws {
        let device = try currentOutputDevice()
        let elements = volumeElements(on: device, requireSettable: true)
        guard !elements.isEmpty else {
            throw ControlError.unavailable("This HDMI, USB, or digital output does not expose software volume control.")
        }

        var scalar = Float(min(1.0, max(0.0, value)))
        for element in elements {
            var address = propertyAddress(
                selector: kAudioDevicePropertyVolumeScalar,
                element: element
            )
            let status = AudioObjectSetPropertyData(
                device,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<Float>.size),
                &scalar
            )
            guard status == noErr else {
                throw ControlError.writeFailed("The current output volume could not be changed (CoreAudio \(status)).")
            }
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

    private func currentOutputDevice() throws -> AudioDeviceID {
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

    private func volumeElements(on device: AudioDeviceID, requireSettable: Bool) -> [AudioObjectPropertyElement] {
        for element in candidateElements(on: device) {
            var address = propertyAddress(selector: kAudioDevicePropertyVolumeScalar, element: element)
            if AudioObjectHasProperty(device, &address) && (!requireSettable || isSettable(device: device, address: &address)) {
                if element == kAudioObjectPropertyElementMain {
                    return [element]
                }
            }
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
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
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
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }
}

