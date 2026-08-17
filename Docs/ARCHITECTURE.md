# Architecture

## Design boundaries

### Input boundary

`ECPrivateAPIBridge.c` is the only place that knows the private MultitouchSupport callback ABI and contact memory layout. The current 96-byte layout was verified on macOS 26.5 arm64 and remains an assumption everywhere else. The bridge copies only contact identifier, normalized X/Y, and raw state into a small public C record. `TrackpadManager` immediately copies those records into Swift value types.

Automatic input preserves the established `MTDeviceCreateDefault` path. Explicit selection resolves `MTDeviceCreateList`, `MTDeviceIsBuiltIn`, and `MTDeviceGetSensorSurfaceDimensions` at runtime. Built-in mode prefers a default device positively identified as built in, then falls back to enumeration. External mode fails closed unless a device is non-built-in and has landscape sensor dimensions; this prevents a known portrait-shaped Magic Mouse surface from being selected. A retained device-list array owns an enumerated device for the complete bridge lifetime. All of these private ABI and shape assumptions require physical revalidation.

`TrackpadManager` is an explicit `@unchecked Sendable` owner. This is justified only because:

1. the undocumented callback may arrive on any thread;
2. it copies memory synchronously before the callback returns;
3. all mutable Swift frame state and handler access run on one serial processing queue;
4. C close marks the handle closing, stops/unregisters the callback, and waits for callbacks already in flight.

Every additional macOS/architecture target must confirm that those assumptions still match its real ABI.

### Recognition boundary

`GestureEngine` imports Foundation only. It accepts `TouchFrame` values and emits `EdgeGestureEvent` values. It does not know about C records, CoreAudio, displays, UI, haptics, or settings.

Eligibility is assigned only on the first non-empty frame of a contact lifecycle. The engine never “rescues” an interior-born contact after it reaches the edge. Multi-touch is a global lifecycle latch. Before activation, candidates must remain in a narrow 3% edge corridor and establish 80%-directional vertical intent within 450ms. Active gestures use the wider 8% control corridor and cancel when they leave it.

### Execution boundary

`EdgeControlAppModel` is `@MainActor`. It resolves the independently configured action when an edge emits `.began`, reads that controller’s current value, and creates a control session. Only a successful session freezes the pointer and emits the activation tick.

Every `.changed` event maps cumulative vertical movement against the session’s initial value. Hardware callbacks never call CoreAudio or display APIs directly.

Settings expose Automatic, Built-in, and External Magic Trackpad preferences plus a manual rescan. Runtime status reports the selected kind when classification succeeds. While any touch lifecycle is live, a 750 ms callback-silence watchdog resets recognition; if control is active, it also ends the session and restores cursor movement. Frames that resume after such silence are discarded until an empty frame or explicit bridge restart, so a stranded contact cannot be reinterpreted as a fresh edge birth.

### Controller boundary

- `VolumeController`: public CoreAudio only; default output device is resolved on every operation.
- `BuiltInDisplayBackend`: finds an active built-in display using CoreGraphics, then calls runtime-loaded DisplayServices.
- `ExternalDDCBackend`: enumerates non-built-in online displays and owns isolated DDC handles.
- `DisplayBrightnessController`: refreshes and prioritizes the built-in display at gesture start. External DDC is eligible only when explicitly enabled and backed by a live connection. A `BrightnessControlSession` pins the selected backend for the gesture, so availability changes cannot silently reroute an in-flight adjustment.
- `BuiltInDisplayBackend`: distinguishes display-list query failure from a successful list with no built-in panel. Query failure preserves the last known ID; a valid external-only list clears it for clamshell mode.

### Feedback boundary

- `HapticEngine` chooses between a public AppKit performer and an opt-in private actuator backend.
- `DetentTracker` is pure logic with 2% spacing and hysteresis.
- `CursorController` uses CoreGraphics cursor/mouse association only after activation.
- `HUDController` owns one persistent non-activating, click-through floating `NSPanel` and one observable SwiftUI model; touch updates mutate the model rather than rebuilding `NSHostingView`.
- The normal HUD is a 148×42 single-row capsule. macOS 26 uses native `glassEffect`; older deployment targets use an ultra-thin material capsule. Error content expands to 220×42. Reduce Transparency switches to an opaque system background and Reduce Motion removes the scale transition.

## Lifecycle

On display reconfiguration, an active brightness session ends before brightness backends re-enumerate; an unrelated volume gesture is left alone. Changing the DDC setting follows the same ordering. On wake, the current control session ends, the gesture recognizer resets, display backends refresh, haptics reset, and the trackpad bridge closes and reopens. Trackpad connect/disconnect does not automatically switch devices; the user invokes **Rescan Trackpads**, which performs the same safe session teardown and bridge reopen.

Wake and close/open recovery passed on the reference machine. Display hot-plug, external DDC, and every other OS/hardware combination remain `LOCAL_VALIDATION_REQUIRED`.

## Failure policy

- Missing MultitouchSupport: menu-bar app remains open and reports touch input unavailable.
- Requested trackpad unavailable or rejected by the external-surface filter: the app remains open, shows the selected preference as unavailable, and does not silently control a different device.
- Unsupported audio device: gesture safely ends; HUD can show the error.
- Missing DisplayServices: built-in backend retries discovery at the next gesture, then reports built-in brightness unavailable.
- DDC disabled or disconnected: it is never called as an implicit fallback. DDC failure remains isolated from built-in brightness and app startup.
- Haptic failure: control continues without vibration.
- Cursor freeze failure: control continues with ordinary pointer movement.
