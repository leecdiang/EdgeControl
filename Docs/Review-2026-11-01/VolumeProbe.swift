import CoreAudio
import Foundation
var channels: [UInt32: Float] = [1: 0.2, 2: 0.8]
func ReviewAudioObjectHasProperty(_ device: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>) -> Bool {
    return channels[address.pointee.mElement] != nil
}
func ReviewAudioObjectIsPropertySettable(_ device: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>, _ settable: UnsafeMutablePointer<DarwinBoolean>) -> OSStatus {
    settable.pointee = true
    return noErr
}
func ReviewAudioObjectGetPropertyData(_ device: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>, _ qualifierSize: UInt32, _ qualifier: UnsafeRawPointer?, _ size: UnsafeMutablePointer<UInt32>, _ output: UnsafeMutableRawPointer) -> OSStatus {
    if address.pointee.mSelector == kAudioHardwarePropertyDefaultOutputDevice {
        output.storeBytes(of: AudioDeviceID(42), as: AudioDeviceID.self)
    } else {
        output.storeBytes(of: channels[address.pointee.mElement]!, as: Float.self)
    }
    return noErr
}
func ReviewAudioObjectSetPropertyData(_ device: AudioObjectID, _ address: UnsafePointer<AudioObjectPropertyAddress>, _ qualifierSize: UInt32, _ qualifier: UnsafeRawPointer?, _ size: UInt32, _ input: UnsafeRawPointer) -> OSStatus {
    channels[address.pointee.mElement] = input.load(as: Float.self)
    return noErr
}
@main struct Probe {
    static func main() throws {
        let controller = VolumeController()
        let session = try controller.beginSession()
        print("VOLUME_BALANCE before L=\(channels[1]!) R=\(channels[2]!) initial=\(session.initialValue)")
        try session.setVolume(session.initialValue + 0.01)
        print("VOLUME_BALANCE after L=\(channels[1]!) R=\(channels[2]!)")
        assert(channels[1] == channels[2])
        channels = [1: .nan, 2: .nan]
        let invalid = try controller.beginSession()
        let target = ContinuousValueMapper().targetValue(initialValue: invalid.initialValue, deltaY: 0.01, speedMultiplier: 0.7)
        try invalid.setVolume(target)
        print("VOLUME_NAN initial=\(invalid.initialValue) mappedTarget=\(target) L=\(channels[1]!) R=\(channels[2]!)")
    }
}
