# EdgeControl 1.3.0

Experimental external Magic Trackpad input with explicit device selection, while Automatic preserves the existing default-device path.

## New

- Trackpad source picker: Automatic, Built-in trackpad, or External Magic Trackpad.
- Automatic mode preserves the proven 1.2.x `MTDeviceCreateDefault` behavior.
- Explicit selection dynamically enumerates devices and reports the active source as Built-in, External, or Running when classification is unavailable.
- "Rescan Trackpads" reopens the selected source after connecting or disconnecting a device; the preference persists across launches.

## Safety

- External selection requires a non-built-in, landscape-oriented touch surface. This fail-closed guard is designed to reject portrait-oriented devices such as Magic Mouse and requires real-hardware confirmation.
- Missing enumeration/classification symbols or a missing selected device fail closed with a visible error; Automatic mode remains available.
- A 750ms live-contact callback watchdog resets a stranded candidate or active lifecycle, restores cursor and haptic state when needed, and rejects resumed frames until lift or rescan.
- The 1.2.1 no-jump mapping and all 450ms / corridor / directionality / multi-touch protections remain unchanged.

## Tests and documentation

- The suite now contains 35 tests, adding preference persistence/fallback and the external-surface geometry guard.
- README, architecture, validation, build-status, and OpenClaw handoff documents describe the experimental support and its required hardware matrix.

## Validation status

- Validated on this machine: 35/35 tests, Release and Universal 2 builds, built-in trackpad gestures (450ms admission, corridors, directionality, multi-touch latch, lower-half filter, no-jump mapping), HUD, volume, brightness, and cursor restore.
- External Magic Trackpad / Magic Mouse hardware matrix NOT TESTED yet: no external device was available at release time. The fail-closed shape guard (non-built-in plus landscape surface) and the disconnect watchdog are unit-tested but still need real-hardware confirmation. Haptic feedback location on an external device is not guaranteed by the public AppKit backend; verify it separately.
