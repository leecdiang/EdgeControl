# LOCAL_VALIDATION_REQUIRED checklist

Nothing in this list is claimed to work merely because the repository contains an implementation.

## Build and concurrency

- [ ] Open `EdgeControl.xcodeproj` with the chosen release Xcode version.
- [ ] Run a clean Debug build for Apple Silicon.
- [ ] Run a clean Debug build for Intel or an Intel CI runner.
- [ ] Resolve every Swift strict-concurrency diagnostic without weakening isolation globally.
- [ ] Confirm the bridging callback converts cleanly to the imported C function-pointer type.
- [ ] Run Thread Sanitizer while starting, stopping, sleeping, waking, and quitting.
- [ ] Confirm C callback close cannot race a queued Swift frame into a deallocated owner.

## MultitouchSupport ABI

File: `EdgeControl/PrivateFrameworks/ECPrivateAPIBridge.c`

- [ ] Confirm framework path `/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport`.
- [ ] Confirm symbols `MTDeviceCreateDefault`, `MTRegisterContactFrameCallback`, `MTUnregisterContactFrameCallback`, `MTDeviceStart`, `MTDeviceStop`, and `MTDeviceRelease`.
- [ ] Confirm callback return type and five callback parameters.
- [ ] Confirm `ECMTFingerABI` size, alignment, identifier offset, state offset, and normalized coordinate offset on arm64.
- [ ] Repeat ABI checks on x86_64 if Intel remains supported.
- [ ] Confirm whether empty frames are delivered after the last finger lifts.
- [ ] Confirm contact identifiers remain stable for an entire physical contact.
- [ ] Confirm whether a raw state must be filtered before a contact counts as live.
- [ ] Confirm normalized coordinate range and whether Y increases upward.
- [ ] Confirm internal versus external Apple trackpad enumeration behavior.

## Physical Edge Entry UX

- [ ] Use the Debug raw-touch log to record true outside-to-inside births at both physical edges.
- [ ] Verify a contact born in the center never triggers after visiting an edge.
- [ ] Verify diagonal ingress feels natural.
- [ ] Tune entry strip, inward travel, vertical travel, corridor, and 250 ms deadline on multiple trackpad sizes.
- [ ] Verify two-finger scroll, pinch, three/four-finger gestures, and two-to-one transitions never activate.
- [ ] Verify corridor exit cancels and stays rejected until lift.
- [ ] Confirm activation does not occur from an ordinary palm or resting thumb.

## CoreAudio

- [ ] Test built-in speakers, AirPods/Bluetooth, HDMI, USB DAC, and digital audio.
- [ ] Confirm unsupported software master volume returns unavailable without a crash.
- [ ] Change the default output during and between gestures.
- [ ] Verify channel fallback does not create left/right imbalance.
- [ ] Verify mute reads/writes on devices that expose mute.

## DisplayServices

File: `ECPrivateAPIBridge.c`, symbols `DisplayServicesGetBrightness` and `DisplayServicesSetBrightness`.

- [ ] Confirm the private framework path and both function signatures.
- [ ] Confirm return value semantics (`0` is currently treated as success).
- [ ] Confirm CoreGraphics built-in detection finds the MacBook panel even when the menu bar is on another display.
- [ ] Test clamshell, mirror, Sidecar/AirPlay, sleep/wake, and display reconfiguration.

## Haptics

- [ ] Test `NSHapticFeedbackManager` from an `LSUIElement` background/menu-bar app.
- [ ] Confirm activation ticks happen only after `Active`.
- [ ] Confirm 5% detents do not buzz at a boundary.
- [ ] Do not enable private haptics until the following symbols and signatures are validated: `MTActuatorCreateFromDevice`, `MTActuatorOpen`, `MTActuatorActuate`, `MTActuatorClose`.
- [ ] Replace placeholder private pattern `1` only with independently measured values; do not copy Verge constants or patterns.
- [ ] Confirm actuator open/close and sleep/wake lifetime.

## External DDC

- [ ] Validate legacy `CGDisplayIOServicePort` + `IOFB*` + `IOI2C*` transport on Intel.
- [ ] Confirm I2C destination/reply addressing, reply delay units, reply format, and checksum handling.
- [ ] Test VCP `0x10` get/set on at least two DDC-capable monitors.
- [ ] Confirm unsupported, HDR/XDR, DisplayLink, docked, mirrored, and hot-plug cases fail independently.
- [ ] Implement and validate Apple Silicon IOAV transport only after confirming ABI for `IOAVServiceCreateWithService`, `IOAVServiceReadI2C`, and `IOAVServiceWriteI2C`; they are intentionally not called by this cloud version.
- [ ] Improve CGDisplayID-to-service matching if the legacy framebuffer association is insufficient.

## Pointer and HUD

- [ ] Confirm `CGAssociateMouseAndMouseCursorPosition` freezes only at Active and always restores on end, cancellation, errors, sleep, stop, and quit.
- [ ] Verify pointer behavior with an external mouse connected.
- [ ] Confirm no Accessibility permission is requested by pointer control.
- [ ] Verify the HUD does not activate the app, accept clicks, steal focus, or appear on the wrong display.

## ZERO_PERMISSION_GOAL

- [ ] Test on a clean macOS user account with no prior TCC grants.
- [ ] Confirm no Accessibility prompt.
- [ ] Confirm no Input Monitoring prompt.
- [ ] Confirm no Screen Recording prompt.
- [ ] Confirm no Full Disk Access requirement.
- [ ] Record any OS-version-specific deviations; do not turn this goal into a marketing claim without evidence.

## Release engineering

- [ ] Replace the empty app-icon slots with original artwork.
- [ ] Choose the final bundle identifier and version.
- [ ] Validate Hardened Runtime with private runtime loading.
- [ ] Sign with Developer ID Application.
- [ ] Notarize and staple the app/DMG.
- [ ] Verify Gatekeeper on a second clean Mac.
- [ ] Verify the DMG layout: app left, Applications right, drag installation works.
- [ ] Publish source, MIT license, third-party notices, checksums, and tested hardware/OS matrix.

