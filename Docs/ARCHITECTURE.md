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

Eligibility is assigned only on the first non-empty frame of a contact lifecycle. The engine never “rescues” an interior-born contact after it reaches the edge. Multi-touch is a global lifecycle latch. Before activation, candidates must remain in a narrow 3% edge corridor and establish 80%-directional vertical intent within 450ms. Active gestures use the wider 8% control corridor and cancel when they leave it. The activation direction is committed in `ActiveContact`; displacement beyond the 0.5% noise deadband on the opposite side of the activation baseline cancels even when the crossing occurred gradually through smaller samples.

`RecentKeyboardActivityGuard` uses public CoreGraphics to query only elapsed time since the latest key-down. It does not capture key codes or text. `EdgeControlAppModel` converts that system fact into a boolean admission input, preserving the Foundation-only recognizer boundary. The independent false-touch profile supplies a fixed 600/350/200ms window and 0.6%/0.8%/1.0% left plus 1.2%/1.5%/1.9% right birth strip. All other recognizer safety thresholds remain invariant. Recent typing may reject only idle/candidate states; the rejection remains latched until an empty frame, and Active gestures ignore it.

### Execution boundary

`EdgeControlAppModel` is `@MainActor`. It resolves the independently configured action when an edge emits `.began`, reads that controller’s current value, and creates a control session. Only a successful session freezes the pointer and emits the activation tick.

Every `.changed` event maps cumulative vertical movement against the session’s initial value. The independently selected adjustment-speed multiplier is captured in the control session at activation, so settings changes cannot alter gain mid-gesture. Hardware callbacks never call CoreAudio or display APIs directly.

Settings expose Automatic, Built-in, and External Magic Trackpad preferences plus a manual rescan. Runtime status reports the selected kind when classification succeeds. While any touch lifecycle is live, a 750 ms callback-silence watchdog resets recognition; if control is active, it also ends the session and restores cursor movement. Frames that resume after such silence are discarded until an empty frame or explicit bridge restart, so a stranded contact cannot be reinterpreted as a fresh edge birth.

### Controller boundary

- `VolumeController`: public CoreAudio only; each gesture pins the output device, writable channel layout, and initial channel ratios. Peak channel scalar is the overall value without a master control. All reads must succeed and be finite; partial write failures trigger best-effort rollback.
- `BuiltInDisplayBackend`: finds an active built-in display using CoreGraphics, then calls runtime-loaded DisplayServices.
- `ExternalDDCBackend`: enumerates non-built-in online displays, owns isolated DDC handles, and remembers the connection that successfully returned the initial VCP `0x10` value so writes target the same monitor.
- `DisplayBrightnessController`: refreshes and prioritizes the built-in display at gesture start. External DDC is eligible only when explicitly enabled and backed by a live connection. A `BrightnessControlSession` pins the selected backend for the gesture, so availability changes cannot silently reroute an in-flight adjustment.
- `BuiltInDisplayBackend`: distinguishes display-list query failure from a successful list with no built-in panel. Query failure preserves the last known ID; a valid external-only list clears it for clamshell mode.

### Feedback boundary

- `HapticEngine` chooses between a public AppKit performer and an opt-in private actuator backend.
- `DetentTracker` is pure logic with hysteresis. Standard/Strong use 2% spacing; Light uses 4% spacing. Standard preserves the prior `.alignment` pattern, while Strong uses the public `.generic` pattern because AppKit exposes no amplitude control. Strong's secondary pulse is a cancellable task owned by `HapticEngine`; gesture end and wake reset invalidate it.
- `CursorController` uses CoreGraphics cursor/mouse association only after activation.
- `HUDController` owns one persistent non-activating, click-through floating `NSPanel` and one observable SwiftUI model; touch updates mutate the model rather than rebuilding `NSHostingView`.
- The normal HUD is a 144×40 single-row capsule and error content expands to 212×40. A capsule-clipped `NSVisualEffectView` supplies active `.hudWindow` blur on macOS 13+, with a 52% semantic veil and neutral tint above it. Both AppKit and SwiftUI clip the backdrop to prevent a rectangular ambient plate. System/Classic/Aurora alter only the progress fill strongly; system dynamic colors adapt the two colored palettes to appearance. Reduce Transparency switches to an opaque system background and Reduce Motion removes the scale transition.

### Presentation boundary

- `MenuBarExtra` uses window style so `MenuBarMenuView` can present a 304-point system-material popover. It reads the same `AppSettings` object as the full Settings window; there is no duplicated menu-only state.
- The popover exposes only high-frequency controls: master enablement, both edge assignments, Haptic, HUD, launch at login, Settings, and Quit. Device warnings reflect `EdgeControlAppModel.touchStatus`/`lastError`.
- `SettingsView` separates Controls, Feedback, Devices, and About into system-rendered cards. `EdgeControlAppModel` owns one reusable 560×470 `NSWindow`, preventing duplicate Settings windows and content-dependent resizing.
- `HUDColorStyle` is persisted as a raw value. The old `colorfulHUD` boolean is read only when the new key is absent, mapping false to System and true to Classic.

## Lifecycle

On display reconfiguration, an active brightness session ends before brightness backends re-enumerate; an unrelated volume gesture is left alone. Changing the DDC setting follows the same ordering. Changing false-touch protection or lower-half admission ends the current session, rebuilds recognition, and discards an already-down contact until lift so it cannot become a fresh birth. On wake, the current control session ends, the gesture recognizer resets, display backends refresh, haptics reset, and the trackpad bridge closes and reopens. Trackpad connect/disconnect does not automatically switch devices; the user invokes **Rescan Trackpads**, which performs the same safe session teardown and bridge reopen.

Wake and close/open recovery passed on the reference machine. Display hot-plug, external DDC, and every other OS/hardware combination remain `LOCAL_VALIDATION_REQUIRED`.

## Failure policy

- Missing MultitouchSupport: menu-bar app remains open and reports touch input unavailable.
- Requested trackpad unavailable or rejected by the external-surface filter: the app remains open, shows the selected preference as unavailable, and does not silently control a different device.
- Unsupported audio device: gesture safely ends; HUD can show the error.
- Missing DisplayServices: built-in backend retries discovery at the next gesture, then reports built-in brightness unavailable.
- DDC disabled or disconnected: it is never called as an implicit fallback. DDC failure remains isolated from built-in brightness and app startup.
- Haptic failure: control continues without vibration.
- Cursor freeze failure: control continues with ordinary pointer movement.

## 1.7.6 input and settings lifecycle

Callback receipt time uses system uptime independently of the private device timestamp. TrackpadManager synchronously forwards copied values through its serial processing queue into a locked 32-frame mailbox. Only one MainActor drain task is scheduled. Overflow flags a discontinuity, while frames older than 150ms are rejected before recognition or controller access; both paths require a fresh lift. These changes bound queued work and stop replay after a main-thread delay. Synchronous OS device calls themselves are not interruptible by this guard; moving those calls to a separate session executor remains a possible future latency improvement.

Master/action disablement and edge reassignment synchronously end affected control sessions, restore cursor association, and require lift. HUD and haptic toggles immediately cancel their corresponding feedback. Sparkle owns persistence of automatic checks; About displays and changes that preference without storing a second value in AppSettings.

### Haptic continuity (1.7.7)

Detents remain the primary trigger. A moving value also requests feedback after 120ms (Standard/Strong) or 180ms (Light) when net displacement since the last feedback request reaches a quarter detent (0.5% / 1%). This is a request policy, not a hardware delivery guarantee. Jitter does not accumulate and a stationary value creates no periodic timer. Both endpoints request one tick on arrival.

A cooldown crossing retains only the latest value and schedules one cancellable deadline. Returning inside the threshold, ending/disabling the gesture, starting another gesture, or waking cancels it. Feedback older than 100ms of actual value movement is dropped. Strong secondary feedback is dropped if delayed beyond 42ms from the primary request, and its actual request time participates in the next primary cooldown. Public AppKit performers are acquired per request; private actuator calls remain opt-in and unvalidated.

Release debug logging in OSLog category Haptics distinguishes below-threshold, cooldown, stale, unavailable, and requested outcomes; it does not record touch coordinates. AppKit provides no actuator-delivery acknowledgement.

### Adaptive presentation (1.8.0)

HUDMode owns Capsule / Notch / Off and persists the last visible choice for the menu toggle. Legacy hidden HUD stays hidden. Previously disabled global actions migrate once to explicit disabled edge assignments. The settings UI has only one master switch and two assignments; haptic scheduling and gesture recognition are unchanged.

HUDPlacement is pure point-based geometry, using the target NSScreen's safe top inset and auxiliary left/right areas. Invalid or absent cutout metadata falls back to a top capsule within visibleFrame; Capsule retains lower placement. The content is entirely below the cutout, while the black background meets the top screen edge. The panel is nonactivating and ignores mouse events; notch presentation uses statusBar level. Fullscreen coverage remains a physical validation item.

Brightness sessions capture backend display identity after initial reading. HUD placement follows that identity; volume pins the pointer screen at gesture start. Hotplug reselects an available screen and recomputes geometry. This metadata does not reroute device writes. Preview actions issue no volume/brightness writes and are suppressed during active control. Alcove installation detection does not change settings, launch it, synthesize keys, or promise external HUD delivery.

### Compact refinement (1.8.1)

The capsule again uses 144×40 pt (212×40 for errors). Notch geometry adds only 8 pt total width to the reported cutout, subject to the content minimum, and 24 pt below it; all content remains outside the physical cutout. The notch fades without scaling to avoid separating its silhouette from the hardware. Preview and live placement share the same resolver. Off is a visibility setting, not a third-party transport. Alcove HUD dispatch is not implemented.

### Presentation state and glass (1.8.2)

EdgeHUDView renders immutable inputs. LiveEdgeHUDView observes the live controller model, while HUDStylePreview derives its geometry directly from mode and style; there is no preview StateObject or onChange copy. Repeated changes in one hosted view are covered by rendered silhouette assertions. The production settings content factory is reused in snapshots so the NSVisualEffectView and appearance-aware scrim are included. Settings no longer cover the backdrop with an opaque SwiftUI root. Liquid Glass is limited to navigation and preview controls on macOS 26+; content cards use regular material, and Reduce Transparency provides solid backgrounds. MenuBarExtra retains its system material with an added 18% neutral scrim. No gesture, device-write or haptic scheduling changes.
