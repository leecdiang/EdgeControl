import XCTest
@testable import EdgeControl

final class MappingTests: XCTestCase {
    func testContinuousMappingUsesInitialValueAndCumulativeDelta() {
        let mapper = ContinuousValueMapper(baseGain: 1.0)
        XCTAssertEqual(
            mapper.targetValue(initialValue: 0.40, deltaY: 0.20, sensitivity: 1.5),
            0.70,
            accuracy: 0.000_001
        )
    }

    func testMappingClampsToUnitInterval() {
        let mapper = ContinuousValueMapper(baseGain: 1.0)
        XCTAssertEqual(mapper.targetValue(initialValue: 0.95, deltaY: 0.20, sensitivity: 1.0), 1.0)
        XCTAssertEqual(mapper.targetValue(initialValue: 0.05, deltaY: -0.20, sensitivity: 1.0), 0.0)
    }

    func testSensitivityChangesGain() {
        let mapper = ContinuousValueMapper(baseGain: 1.0)
        let low = mapper.targetValue(initialValue: 0.50, deltaY: 0.10, sensitivity: 0.5)
        let high = mapper.targetValue(initialValue: 0.50, deltaY: 0.10, sensitivity: 2.0)
        XCTAssertEqual(low, 0.55, accuracy: 0.000_001)
        XCTAssertEqual(high, 0.70, accuracy: 0.000_001)
    }
}

