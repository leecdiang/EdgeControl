# HANDOFF TO OPENCLAW

This is the operational handoff for the local macOS agent. The cloud stage completed the repository structure and implementation but had no macOS SDK, Xcode, MacBook trackpad, Taptic Engine, built-in display, external DDC monitor, signing identity, or notarization credentials. Treat every real-hardware result as unknown until measured.

## A. What is already implemented

### Project and application shell

- A complete `EdgeControl.xcodeproj` with shared `EdgeControl` scheme.
- macOS application target and hosted XCTest target.
- Deployment target macOS 13.0; Apple Silicon and Intel use standard Xcode architectures.
- `LSUIElement=true`; the app is menu-bar-only and has no default Dock icon.
- SwiftUI `MenuBarExtra` and Settings scene.
- Empty entitlements file and no TCC usage strings, consistent with the unverified zero-permission goal.
- Debug defines `EDGE_DEBUG_LOGGING`; Release does not.
- Strict-concurrency checking is set to `complete` while Swift language mode remains 5 for a staged migration.

### Input pipeline

- `ECPrivateAPIBridge.c/.h` dynamically opens MultitouchSupport and resolves device/callback/start/stop symbols.
- Private callback memory is translated to an owned C record containing identifier, normalized X/Y, and raw state.
- C-side close marks the bridge as closing, stops/unregisters, and waits for callbacks in flight.
- `TrackpadManager` copies raw contacts synchronously, serializes Swift mutation on a dedicated queue, infers began/moved lifecycle phases by stable contact ID, and emits normalized `TouchFrame` values.
- Missing framework/symbol/open failures return a user-visible unavailable state instead of aborting app launch.

### Physical Edge Ingress recognizer

- `GestureEngine` is hardware-independent and Foundation-only.
- Explicit states: idle, entry candidate, entry confirmed, active, rejected, and multi-touch rejected.
- A contact first observed inside the entry strips is permanently rejected for that lifecycle.
- Left births require positive inward X travel; right births require negative inward X travel.
- Vertical intent must be established within 250 ms; natural diagonal entry is accepted.
- Entry strip and 8% control corridor are separate.
- Corridor exit before activation rejects; corridor exit after activation emits cancel and latches rejection until lift.
- Any frame with two or more live contacts cancels an active gesture and latches multi-touch rejection until an empty frame. A two-to-one transition stays rejected.
- Events are decoupled: began, cumulative-delta changed, ended, cancelled.
- The 11 required synthetic cases plus an active-corridor case are covered in `GestureEngineTests`.

### Action mapping

- Independent `EdgeAction` settings for left and right: disabled, volume, brightness. Both edges may use the same action.
- Master, volume, brightness, haptic, HUD, sensitivity, and launch-at-login settings are backed by `UserDefaults`.
- Continuous mapping uses `initialValue + cumulativeDeltaY × baseGain × sensitivity`, clamped to `[0,1]`.
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

### Feedback and UI

- Public AppKit haptic backend.
- Private actuator backend scaffold, dynamically resolved and disabled by default behind `EDGE_ENABLE_UNVALIDATED_PRIVATE_HAPTIC=1`.
- One activation tick only after active control session creation.
- 5% value detents with 0.8% hysteresis; pure `DetentTracker` tests cover boundary bounce.
- Cursor association freezes only after Active; restore occurs on end, cancel, action failure, wake, and stop.
- Custom borderless, non-activating, click-through, floating AppKit `NSPanel` with SwiftUI content, icon, progress, percentage, unavailable message, and fade-out.
- Public `SMAppService.mainApp` launch-at-login controller with rollback to actual service status after errors.
- Wake monitor ends the session, resets recognition/haptic state, refreshes displays, and reopens the trackpad bridge.

### Tests, documentation, and release shell

- `GestureEngineTests`, `MappingTests`, `DetentTests`, `SettingsTests`, and synthetic trace helper.
- MIT license and no third-party source.
- Runtime privacy/no-network statement and static repository guard.
- Native-tools-only release build and DMG scripts.
- DMG layout script positions `EdgeControl.app` left and `Applications` right.
- Full `LOCAL_VALIDATION_REQUIRED` checklist.

## B. Files not compiled on real macOS

Every code and project file is uncompiled in the cloud stage. Do not assume that a file omitted from the risk notes has been compiled.

### Highest-risk compile/ABI files

- `EdgeControl/PrivateFrameworks/ECPrivateAPIBridge.c`
- `EdgeControl/PrivateFrameworks/ECPrivateAPIBridge.h`
- `EdgeControl/EdgeControl-Bridging-Header.h`
- `EdgeControl/Input/TrackpadManager.swift`
- `EdgeControl/Display/ExternalDDCBackend.swift`
- `EdgeControl/Display/BuiltInDisplayBackend.swift`
- `EdgeControl/Feedback/HapticEngine.swift`
- `EdgeControl/Actions/VolumeController.swift`
- `EdgeControl/System/CursorController.swift`
- `EdgeControl/UI/HUDController.swift`
- `EdgeControl/App/EdgeControlAppModel.swift`

### Pure/application Swift still requiring Xcode compile

- `EdgeControl/App/EdgeControlApp.swift`
- `EdgeControl/Input/TouchModels.swift`
- `EdgeControl/Gesture/EdgeGestureTypes.swift`
- `EdgeControl/Gesture/GestureEngine.swift`
- `EdgeControl/Actions/ContinuousValueMapper.swift`
- `EdgeControl/Actions/ControlErrors.swift`
- `EdgeControl/Display/BrightnessBackend.swift`
- `EdgeControl/Display/DisplayBrightnessController.swift`
- `EdgeControl/Feedback/DetentTracker.swift`
- `EdgeControl/UI/MenuBarMenuView.swift`
- `EdgeControl/UI/SettingsView.swift`
- `EdgeControl/Settings/AppSettings.swift`
- `EdgeControl/Settings/EdgeAction.swift`
- `EdgeControl/System/LaunchAtLoginController.swift`
- `EdgeControl/System/SystemEventMonitor.swift`

### Tests and project metadata still requiring Xcode

- All files in `EdgeControlTests/`.
- `EdgeControl.xcodeproj/project.pbxproj` and the shared scheme.
- `Info.plist`, entitlements, and asset catalog.
- Both shell scripts must be run under macOS Bash with native developer tools.

When the first `xcodebuild` exposes mechanical type/import/availability errors, make the smallest compile correction and retain the existing module boundaries.

## C. Private APIs requiring local ABI correction

### MultitouchSupport

Module/file: `ECPrivateAPIBridge.c`.

Current runtime path:

`/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport`

Current symbol assumptions:

- `MTDeviceCreateDefault(void) -> device`
- `MTRegisterContactFrameCallback(device, callback)`
- `MTUnregisterContactFrameCallback(device, callback)`
- `MTDeviceStart(device, 0)`
- `MTDeviceStop(device)`
- `MTDeviceRelease(device)`

Current callback assumption:

`int32 callback(device, ECMTFingerABI *, int32 count, double timestamp, int32 frame)`

Correct the following from actual headers/symbol inspection and trace evidence: return types, parameter widths, callback registration function-pointer type, contact stride/alignment, normalized-coordinate field offsets, state semantics, empty-frame behavior, device retention, and start/stop ordering. The current `ECMTFingerABI` is a commonly observed shape, not locally verified fact.

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

The cloud implementation provides the legacy framebuffer transport through `CGDisplayIOServicePort`, `IOFBGetI2CInterfaceCount`, `IOFBCopyI2CInterfaceForBus`, `IOI2CInterfaceOpen`, `IOI2CSendRequest`, and `IOI2CInterfaceClose`.

Validate the SDK header availability, function return types, I2C addresses, transaction types, `minReplyDelay` units, reply buffer layout, checksums, bus selection, and CGDisplayID association. It may work on Intel and fail on Apple Silicon.

Apple Silicon IOAV transport is deliberately not invoked because its ABI could not be validated. Investigate and independently implement behind the same C/Swift backend boundary only after validating:

- `IOAVServiceCreateWithService`
- `IOAVServiceReadI2C`
- `IOAVServiceWriteI2C`

Do not claim external DDC support on a machine/OS combination until VCP `0x10` get and set both pass physical tests.

## D. Known risks

### Raw multitouch

- A symbol can exist while the contact layout is wrong, causing corrupted coordinates or a crash.
- Device enumeration may choose an external trackpad or no device.
- Last-finger lift may not arrive as an empty callback; the state machine then needs an explicit removal translation based on raw state.
- Y direction may be opposite the mapper assumption.
- Callback teardown and Swift queued frames need Thread Sanitizer coverage.

### Gesture UX

- Default 1.5% entry strip may be too narrow or too wide for real contact-birth quantization.
- A physical outside-to-inside contact may first appear farther inside than assumed.
- Palm rejection performed by macOS may alter birth timing and identifiers.
- Corridor width and 250 ms deadline require tests across trackpad sizes.

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

- **ZERO_PERMISSION_GOAL is unverified.** Dynamic touch access or cursor association may behave differently across macOS releases and managed machines.
- No App Sandbox entitlement is configured. Mac App Store distribution is not a goal.

### Code signing and release

- Hardened Runtime compatibility with all dynamically loaded paths is unverified.
- Bundle identifier, team, Developer ID identity, notarization profile, app icon, and release version are placeholders/local work.
- DMG Finder layout and Gatekeeper must be tested on another clean Mac.

## E. Required local validation order

Follow this order so one unknown does not contaminate later conclusions.

### 1. `xcodebuild` compile

Run `./Scripts/validate_repository.sh`, then a clean Xcode build. Fix project syntax, SDK header, imported C pointer, API availability, and strict-concurrency compile errors. Do not enable private haptics or connect DDC debugging yet.

### 2. Unit tests

Run `./Scripts/build_release.sh test`. All synthetic gesture, mapping, detent, and settings tests must pass. Add regression tests before changing state-machine behavior.

### 3. Raw touch logger

Run Debug with `EDGE_DEBUG_LOGGING`. Confirm device opening, callback cadence, coordinate range/direction, identifier stability, live contact count, empty lift frames, and birth positions. At this stage, temporarily keep master control off so no system values change.

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

### 9. Sleep/wake

Test sleep/wake while idle, candidate, active, with a display attached, and after an output-device change. Confirm touch reopens, display enumeration refreshes, haptic resources reset, and cursor restores.

### 10. External DDC

Validate legacy Intel transport first if an Intel Mac is available. Then implement/validate Apple Silicon IOAV transport behind the existing backend. Test unsupported monitors and hot-plug failure isolation.

### 11. Release build

Run an unsigned Release build, confirm Debug logs are absent, inspect linked frameworks, and verify there is no network dependency or runtime call.

### 12. Signing

Set final bundle ID/team, archive with Developer ID Application, enable Hardened Runtime, and verify private dynamic loading. Inspect with `codesign -dv --verbose=4` and `spctl`.

### 13. DMG

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

- [ ] Real macOS compilation for all Swift/C/project files
- [ ] Apple Silicon build and run
- [ ] Intel build and run, or Intel support removed transparently
- [ ] MultitouchSupport framework path and six device symbols
- [ ] Contact callback signature
- [ ] Contact struct size/alignment/offsets
- [ ] Coordinate range and Y direction
- [ ] Contact phase/lift/identifier behavior
- [ ] Physical ingress birth distribution
- [ ] Complete required gesture matrix
- [ ] Multi-touch latch against system gestures
- [ ] CoreAudio device matrix and live output change
- [ ] DisplayServices symbols/signatures/return semantics
- [ ] Built-in panel selection under multi-display configurations
- [ ] Public haptic behavior in LSUIElement
- [ ] Private actuator signatures, lifetime, and independently tuned pattern, if enabled
- [ ] Cursor freeze/restore on every end/error/lifecycle path
- [ ] Sleep/wake reopen and resource reset
- [ ] DDC legacy transport framing and reply parsing
- [ ] Apple Silicon IOAV transport or declared unsupported
- [ ] External-display hot-plug and failure isolation
- [ ] Clean-account zero-permission goal
- [ ] Hardened Runtime compatibility
- [ ] Developer ID signing
- [ ] Notarization and stapling
- [ ] Final original app icon
- [ ] DMG Finder layout and drag install
- [ ] Gatekeeper verification on a second Mac
- [ ] Release contains no Debug contact logging
- [ ] Release contains no network/telemetry dependency

## Local work remaining, in one paragraph

The remaining work is intentionally the Mac-only evidence layer: make the first real Xcode compile corrections; pass the included tests; calibrate the MultitouchSupport callback/contact ABI and physical edge thresholds from raw traces; verify CoreAudio, DisplayServices, haptics, cursor behavior, sleep/wake, permissions, and optional DDC on actual hardware; then provide final identity/icon, Developer ID signing, notarization, and a tested drag-to-Applications DMG. The application architecture, recognizer, settings, action coordination, UI, tests, and release scaffolding should remain intact unless those measurements demonstrate a structural defect.

