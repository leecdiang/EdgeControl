# EdgeControl 1.3.1 static bug audit

Scope: current 1.3.1 source after the built-in-brightness routing fix. This is a static review on a non-macOS staging machine; it does not replace Xcode, Thread Sanitizer, or physical hardware testing. Findings below were documented but deliberately not fixed in the 1.3.1 hotfix.

## Confirmed findings

### High within experimental DDC: VCP reply fields are parsed one byte late

- Evidence: `ec_ddc_get_vcp10` locates the reply command byte (`0x02`) and VCP code at `index + 2`, but then reads maximum from `index + 5/+6` and current from `index + 7/+8`. Relative to the command byte, the usual Get VCP reply places maximum at `+4/+5` and current at `+6/+7`.
- Impact: a compatible monitor can return a valid reply while EdgeControl derives a corrupt maximum/current value or rejects it. This can make experimental DDC reads and subsequent writes fail or use the wrong scale.
- Recommended fix: parse the result/type/maximum/current fields explicitly, validate result code, length and checksum, and add byte-fixture tests before hardware validation.

### High within multi-monitor DDC: read and write can target different displays

- Evidence: `ExternalDDCBackend.getBrightness()` returns the first connection that responds, while `setBrightness()` always uses `connections.first`.
- Impact: if the first external display does not answer reads but a later display does, the session initial value comes from the later display and writes then fail against—or change—the first display.
- Recommended fix: make session creation select and pin the responding `Connection`, including its maximum, for both reads and writes.

### Medium: frames queued before trackpad stop can be delivered after restart

- Evidence: `receive()` queues `deliver()` asynchronously. `stop()` closes the C handle before synchronously clearing the Swift handler, so already queued deliveries may invoke the old handler and enqueue MainActor work while stop/restart is in progress. There is no source-generation token on a frame.
- Impact: after Rescan Trackpads, wake, or device switching, an old contact frame can enter the newly reset recognizer and cause a false candidate, rejection, or delayed control until lift/watchdog reset.
- Recommended fix: attach a monotonically increasing generation to queued frames and drop frames whose generation no longer matches; invalidate the generation before closing the old handle.

### Medium: a volume gesture does not pin its output device

- Evidence: `getVolume()` resolves the default output at activation, while every `setVolume()` resolves it again. Only brightness has a pinned per-gesture backend/session.
- Impact: if AirPods, HDMI, or another output becomes default during a gesture, the new device can receive values derived from the old device's initial volume, producing a jump.
- Recommended fix: introduce a volume session that pins `AudioDeviceID` and its writable elements, then cancel it on default-output-device change.

### Low: a successful zero-display result is treated as query failure

- Evidence: `BuiltInDisplayBackend.activeDisplayIDs()` returns `nil` when CoreGraphics succeeds with `count == 0`; `nil` means “preserve the last ID,” whereas an empty array means “successfully found no built-in display.”
- Impact: in a transient headless/sleep transition the backend can retain a stale built-in display ID and report a read/write failure before the next stable refresh.
- Recommended fix: return `[]` for a successful zero count and reserve `nil` only for non-success CoreGraphics results.

## Hardware-dependent risks still open

- `TrackpadManager` records `rawState` but does not translate explicit ended/cancelled states. If a device/OS omits the final empty callback, lift still depends on the 750ms watchdog.
- `ec_ddc_open` accepts the first I2C bus that opens rather than proving that the bus answers DDC/CI. Multi-bus displays, docks, adapters, and Apple Silicon paths require physical verification.
- The private MultitouchSupport callback ABI and external-device classification remain architecture/OS dependent; Intel and external Magic Trackpad runtime behavior are not established by static inspection.

## 1.3.1 hotfix conclusion

No additional defect was found in the new built-in-only routing gates themselves during static review. The five findings above are separate follow-up work. Because DDC is experimental and disabled by default, its two high-severity findings do not block the built-in-only 1.3.1 fix, but the release must not claim validated external DDC support.
