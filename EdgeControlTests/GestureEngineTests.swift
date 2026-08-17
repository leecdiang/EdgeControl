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
        guard case let .changed(edge: .left, deltaY, _) = events[1] else {
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
        guard case let .changed(edge: .left, deltaY, _) = events[1] else {
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
        guard case let .changed(edge: .left, deltaY, _) = events[1] else {
            return XCTFail("expected changed(left), got \(events[1])")
        }
        XCTAssertEqual(deltaY, 0.03, accuracy: 0.0001)
        guard case .cancelled(edge: .left) = events[2] else {
            return XCTFail("expected cancelled(left), got \(events[2])")
        }
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
        guard case let .changed(edge: .left, deltaY, y) = events[1] else {
            return XCTFail("expected changed(left), got \(events[1])")
        }
        XCTAssertEqual(deltaY, 0.03, accuracy: 0.0001)
        XCTAssertEqual(y, 0.58, accuracy: 0.0001)
    }
}
