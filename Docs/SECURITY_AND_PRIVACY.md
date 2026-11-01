# Security and privacy

## Runtime data flow

Touch contacts are processed in memory and reduced to identifier, normalized coordinates, timestamp, and phase. Release builds do not persist or transmit traces. Debug builds can print normalized values and an opt-in raw ABI dump for local hardware tuning. Both Swift and C diagnostics are compile-gated by `EDGE_DEBUG_LOGGING`; the Release configuration excludes them.

The recent-typing guard asks Quartz only for the elapsed time since the last key-down event, and does not query while EdgeControl's master switch is off. It installs no event tap or global monitor, never receives a key code or text value, and stores no keyboard activity. This design still requires a clean-account check on each target macOS version to confirm that no TCC prompt appears.

## Network posture

EdgeControl has no account, analytics, telemetry, or cloud backend. Sparkle checks the GitHub-hosted update feed and downloads updates over the network. Automatic checks are enabled by default; the About tab exposes Sparkle's saved preference, and manual checks remain available. Touch contacts are not included in update requests. Repository string checks are not proof that a dependency performs no networking.

## Permission posture

The project asks for no TCC usage description and carries an empty entitlement file. That reflects a **ZERO_PERMISSION_GOAL**, not evidence that every supported macOS version will behave without Accessibility, Input Monitoring, Screen Recording, or other prompts. Validate on clean accounts and record exact OS/build/hardware combinations.

## Private API posture

Private frameworks are not hard-linked. Dynamic lookup protects startup when frameworks or symbols are absent, but it does not guarantee ABI compatibility when a symbol exists. The C bridge is the trust boundary for raw memory and function-pointer calls.

The private haptic backend is disabled unless the local process environment explicitly sets `EDGE_ENABLE_UNVALIDATED_PRIVATE_HAPTIC=1`. Do not ship with that override until its signatures, lifetime, and pattern values are corrected and validated.
