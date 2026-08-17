# Architecture

## Design boundaries

### Input boundary

`ECPrivateAPIBridge.c` is the only place that knows the private MultitouchSupport callback ABI and contact memory layout. The current 96-byte layout was verified on macOS 26.5 arm64 and remains an assumption everywhere else. The bridge copies only contact identifier, normalized X/Y, and raw state into a small public C record. `TrackpadManager` immediately copies those records into Swift value types.

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

### Controller boundary

- `VolumeController`: public CoreAudio only; default output device is resolved on every operation.
- `BuiltInDisplayBackend`: finds an active built-in display using CoreGraphics, then calls runtime-loaded DisplayServices.
- `ExternalDDCBackend`: enumerates non-built-in online displays and owns isolated DDC handles.
- `DisplayBrightnessController`: built-in display first; an external DDC display is used only when built-in control is unavailable. The experimental DDC enable flag is persisted and applied during app-model initialization.

### Feedback boundary

- `HapticEngine` chooses between a public AppKit performer and an opt-in private actuator backend.
- `DetentTracker` is pure logic with 5% spacing and hysteresis.
- `CursorController` uses CoreGraphics cursor/mouse association only after activation.
- `HUDController` owns one persistent non-activating, click-through floating `NSPanel` and one observable SwiftUI model; touch updates mutate the model rather than rebuilding `NSHostingView`.
- The normal HUD is a 148×42 single-row capsule. macOS 26 uses native `glassEffect`; older deployment targets use an ultra-thin material capsule. Error content expands to 220×42. Reduce Transparency switches to an opaque system background and Reduce Motion removes the scale transition.

## Lifecycle

On display reconfiguration, brightness backends re-enumerate. On wake, the current control session ends, the gesture recognizer resets, display backends refresh, haptics reset, and the trackpad bridge closes and reopens.

Wake and close/open recovery passed on the reference machine. Display hot-plug, external DDC, and every other OS/hardware combination remain `LOCAL_VALIDATION_REQUIRED`.

## Failure policy

- Missing MultitouchSupport: menu-bar app remains open and reports touch input unavailable.
- Unsupported audio device: gesture safely ends; HUD can show the error.
- Missing DisplayServices: built-in backend becomes unavailable.
- DDC failure: external backend fails independently; it never breaks built-in brightness or app startup.
- Haptic failure: control continues without vibration.
- Cursor freeze failure: control continues with ordinary pointer movement.
