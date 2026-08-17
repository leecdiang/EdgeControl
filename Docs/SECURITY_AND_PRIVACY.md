# Security and privacy

## Runtime data flow

Touch contacts are processed in memory and reduced to identifier, normalized coordinates, timestamp, and phase. Release builds do not persist or transmit traces. Debug builds can print normalized values and an opt-in raw ABI dump for local hardware tuning. Both Swift and C diagnostics are compile-gated by `EDGE_DEBUG_LOGGING`; the Release configuration excludes them.

## Network posture

The application target contains no networking library, URL session, analytics SDK, telemetry client, account code, updater, backend, or cloud integration. Release distribution checks should retain this property.

## Permission posture

The project asks for no TCC usage description and carries an empty entitlement file. That reflects a **ZERO_PERMISSION_GOAL**, not evidence that every supported macOS version will behave without Accessibility, Input Monitoring, Screen Recording, or other prompts. Validate on clean accounts and record exact OS/build/hardware combinations.

## Private API posture

Private frameworks are not hard-linked. Dynamic lookup protects startup when frameworks or symbols are absent, but it does not guarantee ABI compatibility when a symbol exists. The C bridge is the trust boundary for raw memory and function-pointer calls.

The private haptic backend is disabled unless the local process environment explicitly sets `EDGE_ENABLE_UNVALIDATED_PRIVATE_HAPTIC=1`. Do not ship with that override until its signatures, lifetime, and pattern values are corrected and validated.
