import XCTest
@testable import EdgeControl

final class DetentTests: XCTestCase {
    func testDetentRequiresHysteresisAndDoesNotBuzzAtBoundary() {
        var tracker = DetentTracker(interval: 0.05, hysteresis: 0.008)
        tracker.begin(at: 0.48)

        XCTAssertFalse(tracker.shouldEmit(for: 0.503))
        XCTAssertTrue(tracker.shouldEmit(for: 0.509))
        XCTAssertFalse(tracker.shouldEmit(for: 0.501))
        XCTAssertFalse(tracker.shouldEmit(for: 0.497))
        XCTAssertTrue(tracker.shouldEmit(for: 0.491))
    }

    func testResetArmsWithoutImmediatePulse() {
        var tracker = DetentTracker()
        tracker.begin(at: 0.20)
        tracker.reset()
        XCTAssertFalse(tracker.shouldEmit(for: 0.90))
    }
}

