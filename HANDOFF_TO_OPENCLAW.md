# HANDOFF TO OPENCLAW

This is the operational handoff for continued macOS validation and release work. The 1.3.0 source retains the 1.2.1 no-jump mapping and adds experimental built-in/external Magic Trackpad selection, manual rescan, selected-device status, and active-session disconnect recovery. The last evidence-backed binary baseline in `BUILD_REPORT.md` remains 1.1.0; do not publish 1.3.0 until the dedicated matrix in `OPENCLAW_VALIDATE_1.3.0.md` passes. External trackpad input, external DDC, Intel/other macOS versions, Developer ID signing, and notarization remain explicitly unverified.

## A. What is already implemented

### Project and application shell

- A complete `EdgeControl.xcodeproj` with shared `EdgeControl` scheme.
- macOS application target and hosted XCTest target.
- Deployment target macOS 13.0; Apple Silicon and Intel use standard Xcode architectures.
- `LSUIElement=true`; the app is menu-bar-only and has no default Dock icon.
- SwiftUI `MenuBarExtra` and Settings scene.
- Empty entitlements file and no TCC usage strings. Zero-TCC behavior was observed on the reference machine and must be rechecked on other OS/hardware combinations.
- Debug defines `EDGE_DEBUG_LOGGING` for Swift and C; Release excludes both normalized and raw touch diagnostics.
- Strict-concurrency checking is set to `complete` while Swift language mode remains 5 for a staged migration.

### Input pipeline

- `ECPrivateAPIBridge.c/.h` dynamically opens MultitouchSupport and resolves device/callback/start/stop symbols.
- Automatic input deliberately preserves `MTDeviceCreateDefault`, matching 1.2.x behavior. Explicit selection additionally resolves device-list, built-in identity, and sensor-dimension metadata at runtime.
- Built-in mode prefers a positively identified built-in default device before list fallback. External mode selects the first non-built-in landscape surface and fails closed when none matches, so it does not silently fall back or accept a portrait-shaped Magic Mouse surface.
- The bridge retains the device-list array for as long as an enumerated device is active. Settings provide Automatic/Built-in/External, selected-kind status, persistence, and a manual **Rescan Trackpads** action.
- Private callback memory is translated to an owned C record containing identifier, normalized X/Y, and raw state.
- C-side close marks the bridge as closing, stops/unregisters, and waits for callbacks in flight.
- `TrackpadManager` copies raw contacts synchronously, serializes Swift mutation on a dedicated queue, infers began/moved lifecycle phases by stable contact ID, and emits normalized `TouchFrame` values.
- Missing framework/symbol/open failures return a user-visible unavailable state instead of aborting app launch.

### Physical Edge Ingress recognizer

- `GestureEngine` is hardware-independent and Foundation-only.
- Explicit states: idle, entry candidate, entry confirmed, active, rejected, and multi-touch rejected.
- A contact first observed in the trackpad interior (outside both entry strips) is permanently rejected for that lifecycle.
- Edge-pinned hardware reports little or no measurable inward X travel, so ingress is inferred from edge birth plus outward-motion rejection rather than a positive inward threshold.
- Vertical intent must be established within 450 ms; natural diagonal entry is accepted.
- Candidate contacts are limited to a 3% edge corridor; Active contacts retain an 8% control corridor.
- At least 80% of the pre-activation vertical path must stay in one direction. Candidate/active corridor exit rejects or cancels and latches until lift.
- Any frame with two or more live contacts cancels an active gesture and latches multi-touch rejection until an empty frame. A two-to-one transition stays rejected.
- Events are decoupled: began, cumulative-delta changed, ended, cancelled.
- Twenty gesture tests cover the required matrix, timeout boundary, candidate/active corridor split, directionality, lower-half admission, and zero-cross cancellation.

### Action mapping

- Independent `EdgeAction` settings for left and right: disabled, volume, brightness. Both edges may use the same action.
- Master, volume, brightness, haptic, HUD, sensitivity, launch-at-login, and external-DDC settings are backed by `UserDefaults`.
- Continuous mapping uses `initialValue + cumulativeDeltaY × baseGain × sensitivity`, clamped to `[0,1]`.
- Lower-half-only is strictly an admission filter. It never maps absolute finger height to volume or brightness, so activation cannot cause a value jump.
- The input callback never executes an action. `EdgeControlAppModel` opens an action session only after `.began` and a successful initial-value read.

### Volume

- Public CoreAudio implementation for get/set volume and get/set mute.
- Default output device is resolved on every operation, so output changes do not leave a stale device ID.
- Master output element is preferred; left/right channel elements are a fallback.
- Property presence and settable status are checked. HDMI/USB/digital devices without software scalar volume return unavailable rather than crash.

### Brightness

- CoreGraphics enumerates active displays and explicitly selects `CGDisplayIsBuiltin`, rather than assuming `CGMainDisplayID` is the panel.
- DisplayServices is runtime-loaded and resolves `DisplayServicesGetBrightness` and `DisplayServicesSetBrightness` without a hard private-framework link.
- External DDC is isolated behind `ExternalDDCBackend`; it enumerates non-built-in online displays, owns one legacy I2C connection per responsive display, and implements DDC/CI VCP `0x10` get/set framing.
- `DisplayBrightnessController` prioritizes the built-in display and falls back to external DDC only when built-in control is unavailable.
- Reconfiguration refreshes display enumeration. DDC errors do not affect built-in brightness or startup.
- The external-DDC toggle now persists immediately and is applied when the app model starts.

### Feedback and UI

- Public AppKit haptic backend.
- Private actuator backend scaffold, dynamically resolved and disabled by default behind `EDGE_ENABLE_UNVALIDATED_PRIVATE_HAPTIC=1`.
- One activation tick only after active control session creation.
- 2% value detents with 0.8% hysteresis; pure `DetentTracker` tests cover boundary bounce.
- Cursor association freezes only after Active; restore occurs on end, cancel, action failure, wake, and stop.
- One persistent borderless, non-activating, click-through `NSPanel` with an observable SwiftUI model (no per-frame `NSHostingView` rebuild).
- Compact 148×42 single-row normal HUD, 220×42 error state, native macOS 26 Liquid Glass, macOS 13–15 ultra-thin fallback, custom progress capsule, and Reduce Motion-aware presentation.
- Public `SMAppService.mainApp` launch-at-login controller with rollback to actual service status after errors.
- Wake monitor ends the session, resets recognition/haptic state, refreshes displays, and reopens the trackpad bridge.
- A 750 ms live-contact callback-silence watchdog resets recognition and, when active, ends the session and restores cursor movement if Bluetooth loss prevents a final touch frame. Resumed frames are discarded until an empty frame or bridge restart, preventing the stranded touch from becoming a fresh edge birth. This does not claim automatic device discovery; connect/disconnect changes require manual rescan or restart.

### Tests, documentation, and release shell

- `GestureEngineTests`, `MappingTests`, `DetentTests`, `SettingsTests`, `HapticEngineTests`, and synthetic trace helper (35 test methods in current source).
- MIT license and no third-party source.
- Runtime privacy/no-network statement and static repository guard.
- Native-tools-only release build and DMG scripts.
- DMG layout script positions `EdgeControl.app` left and `Applications` right.
- Full `LOCAL_VALIDATION_REQUIRED` checklist.

## B. Validation status

The 1.1.0 baseline passed Debug/Release builds and 26 tests on macOS 26.5 arm64. Raw touch, CoreAudio, built-in brightness, public haptics, cursor freeze, sleep/wake, permissions, icon assets, and DMG installation were exercised there.

The current source includes the 1.2.0 hardening, 1.2.1 no-jump mapping, and experimental 1.3.0 trackpad-source changes. Before another binary is published, rerun:

1. `./Scripts/validate_repository.sh`
2. `./Scripts/build_release.sh test` (expect 35 tests)
3. `./Scripts/build_release.sh build`
4. Physical edge-entry regression for 450ms / 3% / 0.80
5. HUD visual/accessibility regression on macOS 26 and at least one pre-26 system
6. Lower-half regression at low and high initial values: activation must preserve the current value, and subsequent up/down motion must remain continuous
7. Complete every Automatic/Built-in/External, Magic Mouse rejection, Bluetooth disconnect, manual-rescan, sleep/wake, and multiple-device scenario in `OPENCLAW_VALIDATE_1.3.0.md`
8. Release binary inspection, DMG packaging, install and launch

Still unvalidated: external DDC hardware, Intel, other macOS versions, Developer ID signing/notarization, and Gatekeeper on a second clean Mac.

## C. Private APIs requiring local ABI correction

### MultitouchSupport

Module/file: `ECPrivateAPIBridge.c`.

Current runtime path:

`/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport`

Current symbol assumptions:

- `MTDeviceCreateDefault(void) -> device`
- `MTDeviceCreateList(void) -> CFArrayRef`
- `MTDeviceIsBuiltIn(device) -> bool`
- `MTDeviceGetSensorSurfaceDimensions(device, int32 *width, int32 *height) -> int32`
- `MTRegisterContactFrameCallback(device, callback)`
- `MTUnregisterContactFrameCallback(device, callback)`
- `MTDeviceStart(device, 0)`
- `MTDeviceStop(device)`
- `MTDeviceRelease(device)`

Current callback assumption:

`int32 callback(device, ECMTFingerABI *, int32 count, double timestamp, int32 frame)`

The 96-byte `ECMTFingerABI` stride and normalized-coordinate fields were verified on macOS 26.5 arm64. The three enumeration/metadata signatures and their ownership semantics have not been verified locally. Revalidate return types, parameter widths, callback registration, contact stride/alignment/offsets, state semantics, empty-frame behavior, device-list retention, device identity, surface orientation, and start/stop ordering on every supported macOS/architecture combination.

### Trackpad actuator

Module/file: `ECPrivateAPIBridge.c`, Swift wrapper `HapticEngine.swift`.

Current candidate symbols:

- `MTActuatorCreateFromDevice`
- `MTActuatorOpen`
- `MTActuatorActuate`
- `MTActuatorClose`

Their signatures, success values, ownership/release, pattern parameter count, and pattern values are unknown. The backend returns unavailable unless the explicit environment opt-in is set. Keep it gated until corrected. Placeholder pattern `1` is not a tuned product value and must not be shipped as such.

### DisplayServices

Module/file: `ECPrivateAPIBridge.c`.

Current runtime path:

`/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices`

Current symbol assumptions:

- `DisplayServicesGetBrightness(CGDirectDisplayID, float *) -> int32`
- `DisplayServicesSetBrightness(CGDirectDisplayID, float) -> int32`
- return value `0` means success

Confirm on every minimum/maximum OS target. If symbol names or result semantics changed, correct only this bridge and keep the Swift backend contract.

### DDC and IOAVService

The current implementation provides the legacy framebuffer transport through `CGDisplayIOServicePort`, `IOFBGetI2CInterfaceCount`, `IOFBCopyI2CInterfaceForBus`, `IOI2CInterfaceOpen`, `IOI2CSendRequest`, and `IOI2CInterfaceClose`.

Validate the SDK header availability, function return types, I2C addresses, transaction types, `minReplyDelay` units, reply buffer layout, checksums, bus selection, and CGDisplayID association. It may work on Intel and fail on Apple Silicon.

Apple Silicon IOAV transport is deliberately not invoked because its ABI could not be validated. Investigate and independently implement behind the same C/Swift backend boundary only after validating:

- `IOAVServiceCreateWithService`
- `IOAVServiceReadI2C`
- `IOAVServiceWriteI2C`

Do not claim external DDC support on a machine/OS combination until VCP `0x10` get and set both pass physical tests.

## D. Known risks

### Raw multitouch

- A symbol can exist while the contact layout is wrong, causing corrupted coordinates or a crash.
- Automatic selection inherits the OS default-device decision. Explicit external selection chooses the first non-built-in landscape surface; list order, sensor orientation, multiple-device behavior, and Magic Mouse rejection require hardware proof.
- Explicit built-in selection prefers a built-in default but may use list fallback; Touch Bar-era hardware must prove that fallback cannot select the wrong built-in multitouch surface.
- A Bluetooth disconnect may stop callbacks without an empty frame. The 750 ms watchdog resets a stranded candidate or active lifecycle; device reconnection still requires manual rescan or restart.
- Last-finger lift may not arrive as an empty callback; the state machine then needs an explicit removal translation based on raw state.
- Y direction may be opposite the mapper assumption.
- Callback teardown and Swift queued frames need Thread Sanitizer coverage.

### Gesture UX

- The independently tuned 0.8% left / 1.5% right entry strips may need adjustment on other trackpad models.
- A physical outside-to-inside contact may first appear farther inside than assumed.
- Palm rejection performed by macOS may alter birth timing and identifiers.
- The new 3% candidate corridor, 8% active corridor, 450ms deadline, and 0.80 directionality requirement need physical regression across trackpad sizes.

### Haptic

- Public AppKit haptics may be ignored or routed differently in an `LSUIElement` app.
- The private actuator ABI is unsafe until corrected.
- Sleep/wake and device loss can invalidate actuator ownership.

### DisplayServices and DDC

- Private brightness symbols can change or reject a display ID.
- Legacy DDC is deprecated and not expected to cover all Apple Silicon paths.
- A monitor may acknowledge VCP `0x10` but use a non-100 maximum or delayed response.
- Hot-plug may invalidate a connection during a gesture.
- DisplayLink, XDR/HDR, mirroring, docks, and adapters are intentionally unsupported edge cases, not targets for hacks.

### Swift concurrency

- Complete strict-concurrency checking may report actor-isolation issues around C callbacks, AppKit completion handlers, `deinit`, or NotificationCenter on the local Xcode version.
- Do not silence the project with global `@preconcurrency` or weaker checking. Keep `@unchecked Sendable` limited to the owner whose serial-queue invariants are documented.

### Sleep/wake and lifecycle

- Reopening the private trackpad while a stale C callback is draining must be tested.
- App termination should always re-associate cursor movement.
- A crash during cursor freeze could leave association disabled until another process restores it; validate recovery behavior.

### Permission and sandbox

- Zero-TCC operation passed on the reference machine, but dynamic touch access or cursor association may behave differently across macOS releases and managed machines.
- No App Sandbox entitlement is configured. Mac App Store distribution is not a goal.

### Code signing and release

- The ad-hoc Release ran with Hardened Runtime on the reference machine; Developer ID/notarization behavior remains unverified.
- Bundle identifier, version, and app icon are populated. Team, Developer ID identity, and notarization profile still require owner credentials.
- DMG Finder layout and Gatekeeper must be tested on another clean Mac.

## E. Required regression and release-validation order

Follow this order so one unknown does not contaminate later conclusions.

### 1. `xcodebuild` compile

Run `./Scripts/validate_repository.sh`, then a clean Xcode build. Treat any new SDK, ABI, API-availability, or strict-concurrency diagnostic as a release blocker. Do not enable private haptics or DDC debugging yet.

### 2. Unit tests

Run `./Scripts/build_release.sh test`. All synthetic gesture, mapping, detent, and settings tests must pass. Add regression tests before changing state-machine behavior.

### 3. Raw touch logger

Run Debug with `EDGE_DEBUG_LOGGING`. Confirm each selection mode, selected-kind probe, surface dimensions, device opening, callback cadence, coordinate range/direction, identifier stability, live contact count, empty lift frames, and birth positions. Prove Magic Mouse rejection. At this stage, temporarily keep master control off so no system values change.

### 4. Edge Entry detector

Exercise each required positive/negative gesture and tune only `GestureConfiguration`. Verify physical ingress, diagonal ingress, interior permanent rejection, wrong-direction rejection, timeout, corridor cancellation, all multi-finger system gestures, and reset after all fingers lift.

### 5. CoreAudio

Test get/set/mute and default-output changes independently of touch first. Then enable one edge for volume. Confirm continuous mapping, clamp, device unavailability HUD, and safe cancellation.

### 6. DisplayServices

Confirm built-in display enumeration and get/set directly, then enable brightness on one edge. Test with an external main display so built-in selection is not accidentally `CGMainDisplayID`.

### 7. Haptic

Test the public backend from the menu-bar app. Confirm activation timing and detent hysteresis. Only then inspect/correct the private actuator under a local opt-in; keep public as the shipping default unless physical evidence favors the private backend.

### 8. Zero-permission test

Use a clean user account/VM plus real hardware where needed. Record every TCC prompt and system setting. Do not reuse an account with previous grants.

### 9. External trackpad and lifecycle

Run the complete hardware matrix in `OPENCLAW_VALIDATE_1.3.0.md`: device preference persistence, missing-device failure, built-in/external isolation, multiple external devices, connection plus manual rescan, active Bluetooth disconnect and 750 ms cursor recovery, sleep/wake, relaunch, lower-half continuity, and haptic behavior. Treat every unchecked item as a release blocker for the 1.3.0 external-input claim.

### 10. Sleep/wake

Test sleep/wake while idle, candidate, active, with a display attached, and after an output-device change. Confirm touch reopens, display enumeration refreshes, haptic resources reset, and cursor restores.

### 11. External DDC

Validate legacy Intel transport first if an Intel Mac is available. Then implement/validate Apple Silicon IOAV transport behind the existing backend. Test unsupported monitors and hot-plug failure isolation.

### 12. Release build

Run an unsigned Release build, confirm Debug logs are absent, inspect linked frameworks, and verify there is no network dependency or runtime call.

### 13. Signing

Set final bundle ID/team, archive with Developer ID Application, enable Hardened Runtime, and verify private dynamic loading. Inspect with `codesign -dv --verbose=4` and `spctl`.

### 14. DMG

Run `package_dmg.sh`, notarize/staple, verify the left-app/right-Applications presentation, drag installation, first launch, quarantine/Gatekeeper behavior, and checksum on a second clean Mac.

## F. Do-not-refactor principle

> Unless compilation or real hardware testing proves that a current abstraction has a structural error, do not broadly rewrite the cloud-completed project.

Make evidence-driven, minimal changes. In particular:

- keep `GestureEngine` free of hardware and UI;
- keep private ABI code inside the C bridge;
- keep touch callbacks separated from system-value execution;
- keep DDC optional and isolated;
- keep left/right action configuration independent;
- keep multi-touch rejection latched until all fingers lift;
- keep unavailable features as graceful failures;
- preserve the no-network/no-telemetry boundary;
- add tests before changing recognizer semantics.

A compiler diagnostic justifies a compile correction. A raw trace justifies an ABI/layout correction. A repeatable physical UX failure justifies a recognizer threshold or state transition change. Preference alone is not evidence for a large rewrite.

## G. Per-item `LOCAL_VALIDATION_REQUIRED` checklist

Use [Docs/LOCAL_VALIDATION_REQUIRED.md](Docs/LOCAL_VALIDATION_REQUIRED.md) as the executable checklist. At minimum, do not close the handoff until every item below is either checked with recorded evidence or explicitly declared unsupported:

- [x] Real macOS compilation for the 1.1.0 Swift/C/project baseline
- [x] Apple Silicon build and run
- [ ] Intel build and run, or Intel support removed transparently
- [x] MultitouchSupport framework path and required device symbols on macOS 26.5 arm64
- [ ] Trackpad enumeration/metadata ABI and device-list ownership
- [ ] Automatic/Built-in/External selection matrix and Magic Mouse rejection
- [ ] Active external disconnect watchdog and manual rescan
- [x] Contact callback signature on macOS 26.5 arm64
- [x] Contact struct size/alignment/offsets on macOS 26.5 arm64
- [x] Coordinate range and Y direction on the reference machine
- [x] Contact phase/lift/identifier behavior on the reference machine
- [x] Physical ingress birth distribution on the reference machine
- [ ] Complete required gesture matrix
- [x] Multi-touch latch against system gestures on the reference machine
- [ ] CoreAudio device matrix and live output change
- [x] DisplayServices symbols/signatures/return semantics on macOS 26.5 arm64
- [ ] Built-in panel selection under multi-display configurations
- [x] Public haptic behavior in LSUIElement on the reference machine
- [ ] Private actuator signatures, lifetime, and independently tuned pattern, if enabled
- [x] Cursor freeze/restore on tested end/error/lifecycle paths
- [x] Sleep/wake reopen and resource reset on the reference machine
- [ ] DDC legacy transport framing and reply parsing
- [ ] Apple Silicon IOAV transport or declared unsupported
- [ ] External-display hot-plug and failure isolation
- [ ] Clean-account zero-permission goal
- [x] Hardened Runtime with ad-hoc signing on the reference machine
- [ ] Developer ID signing
- [ ] Notarization and stapling
- [x] Final original app icon
- [x] DMG Finder layout and drag install for the 1.1.0 baseline
- [ ] Gatekeeper verification on a second Mac
- [ ] Release contains no Debug contact logging
- [x] Release contains no network/telemetry dependency

## Local work remaining, in one paragraph

The immediate remaining work is a macOS regression run for the current 35-test source, the stricter 450ms / 3% / 0.80 gesture admission, and the full external-trackpad hardware matrix, followed by a fresh Release build and binary-log inspection. External DDC still needs real monitor testing. Public distribution additionally requires owner-supplied Developer ID credentials, notarization, Gatekeeper verification, and replacement of stale GitHub Release attachments. The existing architecture should remain intact unless those measurements demonstrate a structural defect.
