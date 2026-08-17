# LOCAL_VALIDATION_REQUIRED checklist

Checked items have recorded evidence on the macOS 26.5 arm64 reference machine. Unchecked items, other platforms, and the post-1.1 source hardening are not claimed to work merely because the repository contains an implementation.

## Build and concurrency

- [x] Open and build the 1.1.0 baseline with Xcode 26.6.
- [x] Run clean Debug and Release builds for Apple Silicon (1.1.0 baseline).
- [ ] Rebuild and run all 29 tests after the 450ms / 3% / 0.80 and DDC-persistence changes.
- [ ] Run a clean Debug build for Intel or an Intel CI runner.
- [x] Resolve baseline Swift strict-concurrency diagnostics without weakening isolation globally.
- [x] Confirm the bridging callback converts cleanly to the imported C function-pointer type on Xcode 26.6.
- [ ] Run Thread Sanitizer while starting, stopping, sleeping, waking, and quitting.
- [ ] Confirm C callback close cannot race a queued Swift frame into a deallocated owner.

## MultitouchSupport ABI

File: `EdgeControl/PrivateFrameworks/ECPrivateAPIBridge.c`

- [x] Confirm framework path `/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport` on macOS 26.5.
- [x] Confirm required device/callback/start/stop symbols on macOS 26.5.
- [x] Confirm callback signature on macOS 26.5 arm64.
- [x] Confirm the 96-byte `ECMTFingerABI` stride and normalized-coordinate layout on arm64.
- [ ] Repeat ABI checks on x86_64 if Intel remains supported.
- [ ] Confirm whether empty frames are delivered after the last finger lifts.
- [x] Confirm contact identifiers remain stable for an entire physical contact on the reference machine.
- [ ] Confirm whether a raw state must be filtered before a contact counts as live.
- [x] Confirm normalized coordinate range and upward-increasing Y on the reference machine.
- [ ] Confirm internal versus external Apple trackpad enumeration behavior.

## Physical Edge Entry UX

- [x] Record outside-to-inside births at both physical edges on the reference machine.
- [x] Verify a center-born contact never triggers after visiting an edge.
- [x] Verify baseline diagonal ingress on the reference machine.
- [ ] Regression-test the 450 ms deadline, 3% candidate corridor, 8% active corridor, and 0.80 directionality threshold on multiple trackpad sizes.
- [x] Verify baseline multi-finger and two-to-one rejection on the reference machine.
- [x] Verify corridor exit cancels and stays rejected until lift.
- [x] Record zero activations during the baseline typing/scrolling palm test.

## CoreAudio

- [ ] Test built-in speakers, AirPods/Bluetooth, HDMI, USB DAC, and digital audio.
- [ ] Confirm unsupported software master volume returns unavailable without a crash.
- [ ] Change the default output during and between gestures.
- [ ] Verify channel fallback does not create left/right imbalance.
- [ ] Verify mute reads/writes on devices that expose mute.

## DisplayServices

File: `ECPrivateAPIBridge.c`, symbols `DisplayServicesGetBrightness` and `DisplayServicesSetBrightness`.

- [x] Confirm the private framework path, signatures, and return semantics on macOS 26.5 arm64.
- [ ] Confirm CoreGraphics built-in detection finds the MacBook panel even when the menu bar is on another display.
- [ ] Test clamshell, mirror, Sidecar/AirPlay, sleep/wake, and display reconfiguration.

## Haptics

- [x] Test `NSHapticFeedbackManager` from the reference `LSUIElement` app.
- [x] Confirm activation ticks happen only after `Active`.
- [x] Confirm 5% detents do not buzz at a boundary on the reference machine.
- [ ] Do not enable private haptics until the following symbols and signatures are validated: `MTActuatorCreateFromDevice`, `MTActuatorOpen`, `MTActuatorActuate`, `MTActuatorClose`.
- [ ] Replace placeholder private pattern `1` only with independently measured values; do not copy Verge constants or patterns.
- [ ] Confirm actuator open/close and sleep/wake lifetime.

## External DDC

- [ ] Validate legacy `CGDisplayIOServicePort` + `IOFB*` + `IOI2C*` transport on Intel.
- [ ] Confirm I2C destination/reply addressing, reply delay units, reply format, and checksum handling.
- [ ] Test VCP `0x10` get/set on at least two DDC-capable monitors.
- [ ] Confirm unsupported, HDR/XDR, DisplayLink, docked, mirrored, and hot-plug cases fail independently.
- [ ] Implement and validate Apple Silicon IOAV transport only after confirming ABI for `IOAVServiceCreateWithService`, `IOAVServiceReadI2C`, and `IOAVServiceWriteI2C`; they are intentionally not called by the current implementation.
- [ ] Improve CGDisplayID-to-service matching if the legacy framebuffer association is insufficient.

## Pointer and HUD

- [x] Confirm `CGAssociateMouseAndMouseCursorPosition` freezes only at Active and restores on the tested end, cancellation, error, sleep, stop, quit, and forced-termination paths.
- [ ] Verify pointer behavior with an external mouse connected.
- [ ] Confirm no Accessibility permission is requested by pointer control.
- [ ] Verify the HUD does not activate the app, accept clicks, steal focus, or appear on the wrong display.
- [ ] Inspect the 148×42 Liquid Glass HUD on macOS 26 over light, dark, colorful, and full-screen content.
- [ ] Inspect the ultra-thin material fallback on macOS 13–15.
- [ ] Verify 650 ms normal dismissal, 1.5 s error dismissal, continuous value updates, and normal/error width transitions.
- [ ] Verify Reduce Motion and Reduce Transparency accessibility behavior.

## ZERO_PERMISSION_GOAL

- [ ] Test on a clean macOS user account with no prior TCC grants.
- [x] Confirm no Accessibility prompt on the reference account.
- [x] Confirm no Input Monitoring prompt on the reference account.
- [x] Confirm no Screen Recording prompt on the reference account.
- [x] Confirm no Full Disk Access requirement on the reference account.
- [ ] Record any OS-version-specific deviations; do not turn this goal into a marketing claim without evidence.

## Release engineering

- [x] Populate every app-icon slot with original artwork.
- [x] Populate the bundle identifier and 1.1.0 version.
- [x] Validate the ad-hoc 1.1.0 baseline with Hardened Runtime and private runtime loading.
- [ ] Sign with Developer ID Application.
- [ ] Notarize and staple the app/DMG.
- [ ] Verify Gatekeeper on a second clean Mac.
- [x] Verify the 1.1.0 baseline DMG layout and drag installation.
- [ ] Publish source, MIT license, third-party notices, checksums, and tested hardware/OS matrix.
