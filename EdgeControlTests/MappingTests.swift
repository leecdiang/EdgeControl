import XCTest
@testable import EdgeControl

final class MappingTests: XCTestCase {
    func testZeroMovementKeepsActivationValue() {
        let mapper = ContinuousValueMapper(baseGain: 2.0)
        XCTAssertEqual(
            mapper.targetValue(initialValue: 0.23, deltaY: 0.0, speedMultiplier: 1.0),
            0.23,
            accuracy: 0.000_001
        )
    }

    func testContinuousMappingUsesInitialValueAndCumulativeDelta() {
        let mapper = ContinuousValueMapper(baseGain: 1.0)
        XCTAssertEqual(
            mapper.targetValue(initialValue: 0.40, deltaY: 0.20, speedMultiplier: 1.5),
            0.70,
            accuracy: 0.000_001
        )
    }

    func testMappingClampsToUnitInterval() {
        let mapper = ContinuousValueMapper(baseGain: 1.0)
        XCTAssertEqual(mapper.targetValue(initialValue: 0.95, deltaY: 0.20, speedMultiplier: 1.0), 1.0)
        XCTAssertEqual(mapper.targetValue(initialValue: 0.05, deltaY: -0.20, speedMultiplier: 1.0), 0.0)
    }

    func testAdjustmentSpeedChangesGainOnly() {
        let mapper = ContinuousValueMapper(baseGain: 1.0)
        let precise = mapper.targetValue(
            initialValue: 0.50,
            deltaY: 0.10,
            speedMultiplier: AdjustmentSpeed.precise.gainMultiplier
        )
        let fast = mapper.targetValue(
            initialValue: 0.50,
            deltaY: 0.10,
            speedMultiplier: AdjustmentSpeed.fast.gainMultiplier
        )
        XCTAssertEqual(precise, 0.550, accuracy: 0.000_001)
        XCTAssertEqual(fast, 0.595, accuracy: 0.000_001)
    }

    func testAdjustmentSpeedPresetMultipliersAreStable() {
        XCTAssertEqual(AdjustmentSpeed.precise.gainMultiplier, 0.50)
        XCTAssertEqual(AdjustmentSpeed.standard.gainMultiplier, 0.70)
        XCTAssertEqual(AdjustmentSpeed.fast.gainMultiplier, 0.95)
    }
}
