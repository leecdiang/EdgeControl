import XCTest
@testable import EdgeControl

final class GestureEngineTests: XCTestCase {
    func testLeftIngressThenImmediateUpActivatesLeft() {
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.017, y: 0.53, after: 0.04)

        XCTAssertEqual(trace.events(using: GestureEngine()), [.began(edge: .left)])
    }

    func testRightIngressThenImmediateDownActivatesRight() {
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.995, y: 0.50)
        trace.contact(x: 0.983, y: 0.47, after: 0.04)

        XCTAssertEqual(trace.events(using: GestureEngine()), [.began(edge: .right)])
    }

    func testInteriorBirthCanNeverBecomeEligibleInSameLifecycle() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.50, y: 0.50)
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.020, y: 0.54)

        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.bornInInterior))
    }

    func testEdgeBirthWithoutInwardMotionDoesNotActivate() {
        // Spec F: a tap placed at the edge with no vertical intent never activates.
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.001, y: 0.501, after: 0.05)
        trace.contact(x: 0.001, y: 0.499, after: 0.05)
        trace.contact(x: 0.001, y: 0.50, after: 0.45) // birth delta 0.55s > 450ms

        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.entryTimedOut))
    }

    func testHorizontalMovementIntoCenterCancelsCandidate() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.031, y: 0.501, after: 0.04)

        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.leftControlCorridorExited))
    }

    func testVerticalIntentAfterTimeoutDoesNotActivate() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.018, y: 0.503, after: 0.05)
        // t = 0.01 + 0.05 + 0.45 = 0.51s; birth delta = 0.50s > 450ms.
        trace.contact(x: 0.020, y: 0.54, after: 0.45)

        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.entryTimedOut))
    }

    func testVerticalIntentWithinTunedEntryTimeoutActivates() {
        // Regression for the tuned entryTimeout (see Docs/GestureTuning.md):
        // A slow control slide establishing 1.5% vertical travel at ~0.31s
        // must activate, while a pause beyond 450ms must not.
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.018, y: 0.503, after: 0.05)
        trace.contact(x: 0.020, y: 0.54, after: 0.25) // birth delta = 0.30s < 0.45s

        XCTAssertEqual(trace.events(using: GestureEngine()), [.began(edge: .left)])
    }

    func testDiagonalInwardUpMotionActivates() {
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.40)
        trace.contact(x: 0.018, y: 0.425, after: 0.06)

        XCTAssertEqual(trace.events(using: GestureEngine()), [.began(edge: .left)])
    }

    func testSecondFingerCancelsAndLatchesRejection() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.018, y: 0.53)
        trace.contacts([(1, 0.020, 0.55), (2, 0.40, 0.40)])

        XCTAssertEqual(
            trace.events(using: engine),
            [.began(edge: .left), .cancelled(edge: .left)]
        )
        XCTAssertEqual(engine.state, .multiTouchRejected)
    }

    func testTwoFingersBecomingOneRemainsRejected() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contacts([(1, 0.015, 0.52), (2, 0.50, 0.50)])
        trace.contact(id: 1, x: 0.020, y: 0.56)

        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .multiTouchRejected)
    }

    func testAllFingersLiftThenNewIngressCanActivate() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contacts([(1, 0.005, 0.50), (2, 0.50, 0.50)])
        trace.contact(id: 1, x: 0.018, y: 0.54)
        trace.lift()
        trace.contact(id: 3, x: 0.995, y: 0.50)
        trace.contact(id: 3, x: 0.982, y: 0.47)

        XCTAssertEqual(trace.events(using: engine), [.began(edge: .right)])
    }

    func testInteriorRejectedThenLiftThenEdgeIngressActivates() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(id: 1, x: 0.50, y: 0.50)
        trace.contact(id: 1, x: 0.001, y: 0.50)
        trace.lift()
        trace.contact(id: 2, x: 0.001, y: 0.50)
        trace.contact(id: 2, x: 0.017, y: 0.53)

        XCTAssertEqual(trace.events(using: engine), [.began(edge: .left)])
    }

    func testActiveGestureLeavingCorridorCancelsAndLatches() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.018, y: 0.53)
        trace.contact(x: 0.090, y: 0.56)

        XCTAssertEqual(
            trace.events(using: engine),
            [.began(edge: .left), .cancelled(edge: .left)]
        )
        XCTAssertEqual(engine.state, .rejected(.leftControlCorridorExited))
    }

    func testActiveGestureCanUseWiderControlCorridor() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.018, y: 0.53)
        trace.contact(x: 0.060, y: 0.55)

        let events = trace.events(using: engine)
        XCTAssertEqual(events.count, 2)
        guard case .began(edge: .left) = events[0] else {
            return XCTFail("expected began(left), got \(events[0])")
        }
        guard case let .changed(edge: .left, deltaY) = events[1] else {
            return XCTFail("expected changed(left), got \(events[1])")
        }
        XCTAssertEqual(deltaY, 0.02, accuracy: 0.0001)
    }

    func testBorderlineDirectionalityDoesNotActivate() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.001, y: 0.51, after: 0.05)
        trace.contact(x: 0.001, y: 0.48, after: 0.05)
        // Directionality is exactly 0.75: up 0.01, down 0.03. The stricter
        // 0.80 requirement keeps this oscillating contact out of Active.
        trace.contact(x: 0.001, y: 0.48, after: 0.40)

        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.entryTimedOut))
    }

    func testOscillatingEdgeContactDoesNotActivate() {
        // Palm-like trace (real pattern from live data): born in the left strip,
        // ~450ms of sub-threshold jitter (up 1% then back), then a downward drift.
        // The two-direction path keeps the directionality ratio low, so it must
        // never activate and must time out.
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.0015, y: 0.511, after: 0.05)   // jitter up 1.1%
        trace.contact(x: 0.0015, y: 0.500, after: 0.05)   // jitter back
        trace.contact(x: 0.0018, y: 0.493, after: 0.05)   // drift down 0.7%
        trace.contact(x: 0.0020, y: 0.487, after: 0.05)   // drift down 1.3%
        trace.contact(x: 0.0020, y: 0.481, after: 0.05)   // |dy| = 1.9% now
        // Directionality: up 0.011, down 0.019 -> max/path = 0.019/0.030 = 0.63 < 0.80
        // Extend past the 450ms deadline so the lifecycle times out.
        for _ in 0..<5 {
            trace.contact(x: 0.0020, y: 0.481, after: 0.05)
        }
        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.entryTimedOut))
    }

    func testMonotonicEdgeContactActivates() {
        // Same geometry but a decisive one-directional push must activate.
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.006, y: 0.53, after: 0.05)
        trace.contact(x: 0.006, y: 0.56, after: 0.05)

        let events = trace.events(using: GestureEngine())
        XCTAssertEqual(events.count, 2)
        guard case .began(edge: .left) = events[0] else {
            return XCTFail("expected began(left), got \(events[0])")
        }
        guard case let .changed(edge: .left, deltaY) = events[1] else {
            return XCTFail("expected changed(left), got \(events[1])")
        }
        XCTAssertEqual(deltaY, 0.03, accuracy: 0.0001)
    }

    func testRoundTripGestureSurvivesUntilZeroCrossing() {
        // A deliberate up-then-down round trip keeps working until the net
        // crosses back past the start; only then does the session cancel.
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.005, y: 0.55, after: 0.05)   // activate (net +0.05)
        trace.contact(x: 0.005, y: 0.58, after: 0.05)   // net +0.08 (no cancel)
        trace.contact(x: 0.005, y: 0.48, after: 0.05)   // net -0.02: zero crossing -> cancel

        let events = trace.events(using: GestureEngine())
        XCTAssertEqual(events.count, 3)
        guard case .began(edge: .left) = events[0] else {
            return XCTFail("expected began(left), got \(events[0])")
        }
        guard case let .changed(edge: .left, deltaY) = events[1] else {
            return XCTFail("expected changed(left), got \(events[1])")
        }
        XCTAssertEqual(deltaY, 0.03, accuracy: 0.0001)
        guard case .cancelled(edge: .left) = events[2] else {
            return XCTFail("expected cancelled(left), got \(events[2])")
        }
    }

    func testGradualZeroCrossingCannotEscapeThroughDeadband() {
        // Cross the activation baseline first inside the 0.5% noise deadband,
        // then continue farther in the opposite direction. The committed
        // activation direction must still reject the later frame.
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.005, y: 0.55, after: 0.05)   // activate upward
        trace.contact(x: 0.005, y: 0.58, after: 0.05)   // +0.03
        trace.contact(x: 0.005, y: 0.548, after: 0.05)  // -0.002, deadband
        trace.contact(x: 0.005, y: 0.52, after: 0.05)   // -0.03, reject

        let events = trace.events(using: GestureEngine())
        XCTAssertEqual(events.count, 4)
        guard case .began(edge: .left) = events[0] else {
            return XCTFail("expected began(left), got \(events[0])")
        }
        guard case let .changed(edge: .left, firstDelta) = events[1] else {
            return XCTFail("expected first changed(left), got \(events[1])")
        }
        XCTAssertEqual(firstDelta, 0.03, accuracy: 0.0001)
        guard case let .changed(edge: .left, deadbandDelta) = events[2] else {
            return XCTFail("expected deadband changed(left), got \(events[2])")
        }
        XCTAssertEqual(deadbandDelta, -0.002, accuracy: 0.0001)
        guard case .cancelled(edge: .left) = events[3] else {
            return XCTFail("expected cancelled(left), got \(events[3])")
        }
    }

    func testRecentTypingRejectsLifecycleUntilLift() {
        let engine = GestureEngine()
        let birth = TouchFrame(
            contacts: [TouchContact(id: 1, x: 0.001, y: 0.50, timestamp: 0.01, phase: .began)],
            timestamp: 0.01
        )
        let moved = TouchFrame(
            contacts: [TouchContact(id: 1, x: 0.005, y: 0.56, timestamp: 0.06, phase: .moved)],
            timestamp: 0.06
        )

        XCTAssertTrue(
            engine.process(birth, blockNewGestureForRecentTyping: true).isEmpty
        )
        XCTAssertEqual(engine.state, .rejected(.recentKeyboardActivity))

        // The same physical touch must not become eligible when the keyboard
        // window expires; only a full lift resets the rejection latch.
        XCTAssertTrue(engine.process(moved).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.recentKeyboardActivity))

        XCTAssertTrue(
            engine.process(TouchFrame(contacts: [], timestamp: 0.07)).isEmpty
        )
        XCTAssertEqual(engine.state, .idle)
    }

    func testTypingDuringCandidateRejectsBeforeActivation() {
        let engine = GestureEngine()
        let birth = TouchFrame(
            contacts: [TouchContact(id: 1, x: 0.001, y: 0.50, timestamp: 0.01, phase: .began)],
            timestamp: 0.01
        )
        let candidateMove = TouchFrame(
            contacts: [TouchContact(id: 1, x: 0.005, y: 0.505, timestamp: 0.04, phase: .moved)],
            timestamp: 0.04
        )

        XCTAssertTrue(engine.process(birth).isEmpty)
        XCTAssertTrue(engine.isAwaitingActivation)
        XCTAssertTrue(
            engine.process(candidateMove, blockNewGestureForRecentTyping: true).isEmpty
        )
        XCTAssertEqual(engine.state, .rejected(.recentKeyboardActivity))
    }

    func testRecentTypingDoesNotInterruptActiveGesture() {
        let engine = GestureEngine()
        let birth = TouchFrame(
            contacts: [TouchContact(id: 1, x: 0.001, y: 0.50, timestamp: 0.01, phase: .began)],
            timestamp: 0.01
        )
        let activation = TouchFrame(
            contacts: [TouchContact(id: 1, x: 0.005, y: 0.55, timestamp: 0.06, phase: .moved)],
            timestamp: 0.06
        )
        let activeMove = TouchFrame(
            contacts: [TouchContact(id: 1, x: 0.006, y: 0.58, timestamp: 0.11, phase: .moved)],
            timestamp: 0.11
        )

        XCTAssertTrue(engine.process(birth).isEmpty)
        XCTAssertEqual(engine.process(activation), [.began(edge: .left)])
        XCTAssertFalse(engine.isAwaitingActivation)

        let events = engine.process(
            activeMove,
            blockNewGestureForRecentTyping: true
        )
        XCTAssertEqual(events.count, 1)
        guard case let .changed(edge: .left, deltaY) = events[0] else {
            return XCTFail("expected changed(left), got \(events[0])")
        }
        XCTAssertEqual(deltaY, 0.03, accuracy: 0.0001)
    }

    func testFalseTouchProfilesChangeLeftBirthAdmission() {
        var strongTrace = SyntheticTouchTrace()
        // x = 0.011 sits just outside the Strong strip (0.010) but inside the
        // Standard strip (0.012): Strong must reject it, Standard must accept.
        strongTrace.contact(x: 0.011, y: 0.50)
        strongTrace.contact(x: 0.014, y: 0.53, after: 0.05)
        let strongEngine = GestureEngine(
            configuration: FalseTouchProtection.strong.gestureConfiguration
        )
        XCTAssertTrue(strongTrace.events(using: strongEngine).isEmpty)
        XCTAssertEqual(strongEngine.state, .rejected(.bornInInterior))

        var standardTrace = SyntheticTouchTrace()
        standardTrace.contact(x: 0.011, y: 0.50)
        standardTrace.contact(x: 0.014, y: 0.53, after: 0.05)
        XCTAssertEqual(
            standardTrace.events(
                using: GestureEngine(
                    configuration: FalseTouchProtection.standard.gestureConfiguration
                )
            ),
            [.began(edge: .left)]
        )

        // x = 0.013 sits just outside the Standard strip (0.012) but inside
        // the Light strip (0.015): Standard must reject it, Light must accept.
        var lightTrace = SyntheticTouchTrace()
        lightTrace.contact(x: 0.013, y: 0.50)
        lightTrace.contact(x: 0.016, y: 0.53, after: 0.05)
        XCTAssertEqual(
            lightTrace.events(
                using: GestureEngine(
                    configuration: FalseTouchProtection.light.gestureConfiguration
                )
            ),
            [.began(edge: .left)]
        )
    }

    func testFalseTouchProfilesPreserveAsymmetricRightBirthRange() {
        var strongTrace = SyntheticTouchTrace()
        // x = 0.981 sits just outside the Strong strip (1.8%) but inside the
        // Standard strip (2.2%): Strong must reject it, Standard must accept.
        strongTrace.contact(x: 0.981, y: 0.50)
        strongTrace.contact(x: 0.975, y: 0.47, after: 0.05)
        let strongEngine = GestureEngine(
            configuration: FalseTouchProtection.strong.gestureConfiguration
        )
        XCTAssertTrue(strongTrace.events(using: strongEngine).isEmpty)
        XCTAssertEqual(strongEngine.state, .rejected(.bornInInterior))

        var standardTrace = SyntheticTouchTrace()
        standardTrace.contact(x: 0.981, y: 0.50)
        standardTrace.contact(x: 0.975, y: 0.47, after: 0.05)
        XCTAssertEqual(
            standardTrace.events(
                using: GestureEngine(
                    configuration: FalseTouchProtection.standard.gestureConfiguration
                )
            ),
            [.began(edge: .right)]
        )
    }

    func testLowerHalfOnlyRejectsBirthAboveMidline() {
        var config = GestureConfiguration.default
        config.lowerHalfOnly = true
        let engine = GestureEngine(configuration: config)

        var trace = SyntheticTouchTrace()
        // Born in the upper half (y > 0.5): rejected at birth, no events.
        // No lift: the rejection state must still be latched while the
        // contact is down (lifting would reset the engine to idle).
        trace.contact(x: 0.001, y: 0.80)
        trace.contact(x: 0.005, y: 0.84, after: 0.05)

        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.bornInUpperHalf))
    }

    func testLowerHalfOnlyAllowsBirthAtOrBelowMidline() {
        var config = GestureConfiguration.default
        config.lowerHalfOnly = true
        let engine = GestureEngine(configuration: config)

        // Born at the midline (y = 0.5) is allowed and activates normally.
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.001, y: 0.50)
        trace.contact(x: 0.005, y: 0.55, after: 0.05)
        trace.contact(x: 0.005, y: 0.58, after: 0.05)

        let events = trace.events(using: engine)
        XCTAssertEqual(events.count, 2)
        guard case .began(edge: .left) = events[0] else {
            return XCTFail("expected began(left), got \(events[0])")
        }
        guard case let .changed(edge: .left, deltaY) = events[1] else {
            return XCTFail("expected changed(left), got \(events[1])")
        }
        XCTAssertEqual(deltaY, 0.03, accuracy: 0.0001)
    }
}
