import XCTest
@testable import EdgeControl

final class GestureEngineTests: XCTestCase {
    func testLeftIngressThenImmediateUpActivatesLeft() {
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.005, y: 0.50)
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
        trace.contact(x: 0.005, y: 0.50)
        trace.contact(x: 0.020, y: 0.54)

        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.bornInInterior))
    }

    func testEdgeBirthWithoutInwardMotionDoesNotActivate() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.005, y: 0.50)
        trace.contact(x: 0.000, y: 0.53)

        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.initialMotionNotInward))
    }

    func testHorizontalMovementIntoCenterCancelsCandidate() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.005, y: 0.50)
        trace.contact(x: 0.070, y: 0.501, after: 0.04)
        trace.contact(x: 0.090, y: 0.502, after: 0.04)

        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.leftControlCorridorExited))
    }

    func testVerticalIntentAfterTimeoutDoesNotActivate() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.005, y: 0.50)
        trace.contact(x: 0.018, y: 0.503, after: 0.05)
        // t = 0.01 + 0.05 + 0.80 = 0.86s; birth delta = 0.85s > entryTimeout 0.80s.
        // (0.75 was too close: 0.81 - 0.01 underflows below the double 0.8.)
        trace.contact(x: 0.020, y: 0.54, after: 0.80)

        XCTAssertTrue(trace.events(using: engine).isEmpty)
        XCTAssertEqual(engine.state, .rejected(.entryTimedOut))
    }

    func testVerticalIntentWithinTunedEntryTimeoutActivates() {
        // Regression for the tuned entryTimeout (see Docs/GestureTuning.md):
        // a slow control slide establishing 1.5% vertical travel at ~0.31s
        // must activate, while a pause > 600ms must not.
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.005, y: 0.50)
        trace.contact(x: 0.018, y: 0.503, after: 0.05)
        trace.contact(x: 0.020, y: 0.54, after: 0.25) // t = 0.31s < 0.60s

        XCTAssertEqual(trace.events(using: GestureEngine()), [.began(edge: .left)])
    }

    func testDiagonalInwardUpMotionActivates() {
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.004, y: 0.40)
        trace.contact(x: 0.018, y: 0.425, after: 0.06)

        XCTAssertEqual(trace.events(using: GestureEngine()), [.began(edge: .left)])
    }

    func testSecondFingerCancelsAndLatchesRejection() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.005, y: 0.50)
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
        trace.contact(x: 0.005, y: 0.50)
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
        trace.contact(id: 1, x: 0.005, y: 0.50)
        trace.lift()
        trace.contact(id: 2, x: 0.004, y: 0.50)
        trace.contact(id: 2, x: 0.017, y: 0.53)

        XCTAssertEqual(trace.events(using: engine), [.began(edge: .left)])
    }

    func testActiveGestureLeavingCorridorCancelsAndLatches() {
        let engine = GestureEngine()
        var trace = SyntheticTouchTrace()
        trace.contact(x: 0.005, y: 0.50)
        trace.contact(x: 0.018, y: 0.53)
        trace.contact(x: 0.090, y: 0.56)

        XCTAssertEqual(
            trace.events(using: engine),
            [.began(edge: .left), .cancelled(edge: .left)]
        )
        XCTAssertEqual(engine.state, .rejected(.leftControlCorridorExited))
    }
}

