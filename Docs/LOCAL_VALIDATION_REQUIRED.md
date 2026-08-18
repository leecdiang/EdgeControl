# LOCAL_VALIDATION_REQUIRED checklist

Checked items have recorded evidence on the macOS 26.5 arm64 reference machine. Unchecked items, other platforms, and the post-1.1 source hardening are not claimed to work merely because the repository contains an implementation.

## Build and concurrency

- [x] Open and build the 1.1.0 baseline with Xcode 26.6.
- [x] Run clean Debug and Release builds for Apple Silicon (1.1.0 baseline).
- [ ] Rebuild and run all 60 tests for the 1.5.1 source.
- [ ] Run a clean Debug build for Intel or an Intel CI runner.
- [x] Resolve baseline Swift strict-concurrency diagnostics without weakening isolation globally.
- [x] Confirm the bridging callback converts cleanly to the imported C function-pointer type on Xcode 26.6.
- [ ] Run Thread Sanitizer while starting, stopping, sleeping, waking, and quitting.
- [ ] Confirm C callback close cannot race a queued Swift frame into a deallocated owner.

## MultitouchSupport ABI

File: `EdgeControl/PrivateFrameworks/ECPrivateAPIBridge.c`

- [x] Confirm framework path `/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport` on macOS 26.5.
- [x] Confirm required device/callback/start/stop symbols on macOS 26.5.
- [ ] Confirm `MTDeviceCreateList`, `MTDeviceIsBuiltIn`, and `MTDeviceGetSensorSurfaceDimensions` signatures and ownership on every release architecture.
- [x] Confirm callback signature on macOS 26.5 arm64.
- [x] Confirm the 96-byte `ECMTFingerABI` stride and normalized-coordinate layout on arm64.
- [ ] Repeat ABI checks on x86_64 if Intel remains supported.
- [ ] Confirm whether empty frames are delivered after the last finger lifts.
- [x] Confirm contact identifiers remain stable for an entire physical contact on the reference machine.
- [ ] Confirm whether a raw state must be filtered before a contact counts as live.
- [x] Confirm normalized coordinate range and upward-increasing Y on the reference machine.
- [ ] With only the built-in trackpad available, confirm Automatic and Built-in both report Built-in and produce frames.
- [ ] With both devices available, confirm Automatic preserves system-default behavior and Built-in never selects Touch Bar or an external surface.
- [ ] With both devices available, confirm External reports External and receives frames only from the selected external surface.
- [ ] Confirm External fails safely when no external Magic Trackpad is connected; it must not fall back to built-in.
- [ ] Confirm a connected Magic Mouse is rejected by the portrait-surface heuristic and never drives an edge action.
- [ ] Capture the Debug `[ECProbe] selected trackpad` kind and surface dimensions for each tested Magic Trackpad and Magic Mouse generation.
- [ ] With multiple external trackpads, document which list entry is selected; 1.3.0 intentionally chooses the first matching surface.
- [ ] Connect/disconnect a Magic Trackpad, press **Rescan Trackpads**, and confirm the old bridge closes before the new bridge opens.
- [ ] Disconnect Bluetooth once during a candidate and once during an active gesture; confirm the 750 ms callback watchdog resets recognition, restores cursor movement, ends the HUD session, and permits a clean rescan.
- [ ] Repeat external selection after sleep/wake and after app relaunch.

## Physical Edge Entry UX

- [x] Record outside-to-inside births at both physical edges on the reference machine.
- [x] Verify a center-born contact never triggers after visiting an edge.
- [x] Verify baseline diagonal ingress on the reference machine.
- [ ] Regression-test the 450 ms deadline, 3% candidate corridor, 8% active corridor, and 0.80 directionality threshold on multiple trackpad sizes.
- [x] Verify baseline multi-finger and two-to-one rejection on the reference machine.
- [x] Verify corridor exit cancels and stays rejected until lift.
- [x] Record zero activations during the baseline typing/scrolling palm test.

## Adjustment speed and false-touch protection

- [ ] Confirm Precise / Standard / Fast change only adjustment gain (`0.50×` / `0.70×` / `0.95×`) and do not change activation eligibility.
- [ ] Confirm Strong / Standard / Light typing boundaries are exactly 600ms / 350ms / 200ms: before rejects, after admits a new deliberate lifecycle.
- [ ] Verify left birth widths 0.6% / 0.8% / 1.0% and right widths 1.2% / 1.5% / 1.9% with captured raw traces.
- [ ] For every profile, confirm 450ms deadline, 3% candidate corridor, 8% Active corridor, 0.80 directionality and multi-touch behavior remain unchanged.
- [ ] Type continuously with a palm near each edge; confirm no activation.
- [ ] Keep a typing-rejected touch down beyond the window; it must stay rejected until lift.
- [ ] Start a candidate, type before activation, and confirm terminal rejection until lift.
- [ ] Type during an Active volume and brightness gesture; neither may cancel or jump.
- [ ] Change adjustment speed during an Active gesture and confirm its pinned gain prevents a jump; the next gesture must use the new speed.
- [ ] Change false-touch protection or lower-half admission while a finger is down; that contact must remain discarded until lift.
- [ ] Repeat with key repeat, an external keyboard, Secure Input contexts, sleep/wake, and all protection profiles.
- [ ] On a clean account, confirm no Accessibility or Input Monitoring prompt and no key value/text capture.

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
- [ ] With no external display, perform 20 brightness gestures with DDC off and again with the toggle on; no `No external DDC...` error may appear.
- [ ] Repeat immediately after display scaling changes and three sleep/wake cycles.
- [ ] Confirm a display-change notification ends an active brightness session and the next gesture re-discovers the built-in panel.
- [ ] Confirm a transient active-display query failure preserves the last valid built-in ID, while a successful external-only list clears it in clamshell mode.
- [ ] Confirm a brightness gesture never switches from its activation backend to DDC mid-gesture.

## Haptics

- [x] Test `NSHapticFeedbackManager` from the reference `LSUIElement` app.
- [x] Confirm activation ticks happen only after `Active`.
- [x] Confirm detents do not buzz at a boundary on the reference machine (baseline spacing differed).
- [ ] Confirm Light / Standard / Strong are perceptibly ordered on both built-in and external Magic Trackpad: Light 4% alignment ticks, Standard 2% alignment ticks, Strong 2% generic ticks.
- [ ] Confirm 2% Standard/Strong detents do not double-trigger from Bluetooth frame jitter and 4% Light detents do not feel too sparse.
- [ ] End a Strong gesture immediately after a tick and repeat across sleep/wake; no delayed secondary pulse may occur after end/reset.
- [ ] Do not enable private haptics until the following symbols and signatures are validated: `MTActuatorCreateFromDevice`, `MTActuatorOpen`, `MTActuatorActuate`, `MTActuatorClose`.
- [ ] Replace placeholder private pattern `1` only with independently measured values; do not copy Verge constants or patterns.
- [ ] Confirm actuator open/close and sleep/wake lifetime.

## External DDC

- [ ] Validate legacy `CGDisplayIOServicePort` + `IOFB*` + `IOI2C*` transport on Intel.
- [ ] Confirm I2C destination/reply addressing, reply delay units, reply format, and checksum handling.
- [ ] Test VCP `0x10` get/set on at least two DDC-capable monitors.
- [ ] With two monitors where only the later enumerated monitor answers VCP `0x10`, confirm the read and every write target that same responsive monitor.
- [ ] Confirm unsupported, HDR/XDR, DisplayLink, docked, mirrored, and hot-plug cases fail independently.
- [ ] Implement and validate Apple Silicon IOAV transport only after confirming ABI for `IOAVServiceCreateWithService`, `IOAVServiceReadI2C`, and `IOAVServiceWriteI2C`; they are intentionally not called by the current implementation.
- [ ] Improve CGDisplayID-to-service matching if the legacy framebuffer association is insufficient.

## Pointer and HUD

- [x] Confirm `CGAssociateMouseAndMouseCursorPosition` freezes only at Active and restores on the tested end, cancellation, error, sleep, stop, quit, and forced-termination paths.
- [ ] Verify pointer behavior with an external mouse connected.
- [ ] Verify cursor restoration after active external-trackpad Bluetooth loss and after manual rescan.
- [ ] Confirm no Accessibility permission is requested by pointer control.
- [ ] Verify the HUD does not activate the app, accept clicks, steal focus, or appear on the wrong display.
- [ ] Inspect the 144×40 clipped `.hudWindow` blur over light, dark, colorful, and full-screen content; confirm no rectangular material plate leaks outside the capsule.
- [ ] Confirm the 52% semantic veil is opaque enough for text contrast while retaining visible frosted blur.
- [ ] Inspect the same clipped `.hudWindow` implementation on macOS 13–15.
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
- [x] Populate the bundle identifier, 1.5.1 marketing version, and build number 2.
- [x] Validate the ad-hoc 1.1.0 baseline with Hardened Runtime and private runtime loading.
- [ ] Sign with Developer ID Application.
- [ ] Notarize and staple the app/DMG.
- [ ] Verify Gatekeeper on a second clean Mac.
- [x] Verify the 1.1.0 baseline DMG layout and drag installation.
- [ ] Publish source, MIT license, third-party notices, checksums, and tested hardware/OS matrix.
