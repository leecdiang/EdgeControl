# Haptic continuity review

Baseline: 1.7.6, main 442142a7171a34eaf253aeb1604213082197e9da. Installed version checked as 1.7.6; local settings were Standard haptics and Standard adjustment speed. User confirmed ongoing adjustment with an intermittent silent segment.

## Reproduced request gaps

A recording backend was substituted only for physical output; actual old/new HapticEngine and DetentTracker source was compiled. At values 0.500 (activation), 0.506 at 121ms, and 0.512 at 242ms, old code issued only the activation request (1 total), new code issued 3. Moving from 0.98 to 1 at 40ms issued 0 old endpoint requests versus 1 new request. This proves request-policy differences, not the cause of every reported physical dropout.

A suppressed crossing previously had no scheduled retry; it depended on the next changed event. At the upper endpoint, bucket 49 requires 1.008, which cannot be reached after clamping. The lower endpoint has a corresponding unreachable threshold within bucket 0.

## Coverage

13 new regression tests cover slow movement, Light cadence, jitter, single deferred request, coalescing, return-to-bucket cancellation, end/wake cancellation, stale timer expiry, both endpoints, invalid values, new activation, real timer delivery, and real timer cancellation. Existing Strong lifecycle and cooldown tests remain. Full CI results are recorded in the linked PR.

## Physical validation

Compare continuous slow/fast slides with volume and brightness separately, Standard first, then Light/Strong. Check pauses and lift produce no late tick. Inspect requests with:

```sh
log stream --level debug --style compact --predicate 'subsystem == "org.edgecontrol.EdgeControl" AND category == "Haptics"'
```

`requested` means the public performer was called, not that the actuator fired. Repeated requests during an observed silent interval point beyond detent scheduling. Absence of all records during adjustment may indicate main-thread work; hardware writes remain synchronous. No private actuator ABI or undocumented pattern was enabled.

Apple documentation: https://developer.apple.com/documentation/appkit/nshapticfeedbackperformer/perform(_:performancetime:) documents that the system may override requests. https://developer.apple.com/documentation/appkit/nshapticfeedbackmanager/defaultperformer requires reacquiring the performer as the active device may change; the implementation already does so on every pulse.
