import CoreGraphics
import XCTest
@testable import EdgeControl

@MainActor
final class SettingsTests: XCTestCase {
    func testDefaultActionsAreIndependent() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.leftEdgeAction, .volume)
        XCTAssertEqual(settings.rightEdgeAction, .brightness)
        XCTAssertEqual(settings.adjustmentSpeed, .standard)
        XCTAssertEqual(settings.falseTouchProtection, .standard)
    }

    func testBothEdgesCanUseSameAction() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = AppSettings(defaults: defaults)
        settings.leftEdgeAction = .brightness
        settings.rightEdgeAction = .brightness

        XCTAssertEqual(settings.leftEdgeAction, .brightness)
        XCTAssertEqual(settings.rightEdgeAction, .brightness)
    }

    func testValuesPersistToUserDefaults() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        var settings: AppSettings? = AppSettings(defaults: defaults)
        settings?.masterEnabled = false
        settings?.hapticFeedback = false
        settings?.adjustmentSpeed = .fast
        settings?.falseTouchProtection = .strong
        settings?.leftEdgeAction = .disabled
        settings?.externalDDCEnabled = true
        settings?.trackpadPreference = .external
        settings = nil

        let restored = AppSettings(defaults: defaults)
        XCTAssertFalse(restored.masterEnabled)
        XCTAssertFalse(restored.hapticFeedback)
        XCTAssertEqual(restored.adjustmentSpeed, .fast)
        XCTAssertEqual(restored.falseTouchProtection, .strong)
        XCTAssertEqual(restored.leftEdgeAction, .disabled)
        XCTAssertTrue(restored.externalDDCEnabled)
        XCTAssertEqual(restored.trackpadPreference, .external)
    }

    func testTypingProtectionUsesIndependentProfileBoundaries() {
        for protection in FalseTouchProtection.allCases {
            var elapsed = protection.typingSuppressionInterval - 0.001
            let guardLogic = RecentKeyboardActivityGuard { elapsed }

            XCTAssertTrue(guardLogic.shouldBlock(for: protection.typingSuppressionInterval))
            elapsed = protection.typingSuppressionInterval
            XCTAssertFalse(guardLogic.shouldBlock(for: protection.typingSuppressionInterval))
        }
    }

    func testFalseTouchProfilesChangeOnlyAdmissionValues() {
        XCTAssertEqual(FalseTouchProtection.strong.typingSuppressionInterval, 0.600)
        XCTAssertEqual(FalseTouchProtection.standard.typingSuppressionInterval, 0.350)
        XCTAssertEqual(FalseTouchProtection.light.typingSuppressionInterval, 0.200)

        let strong = FalseTouchProtection.strong.gestureConfiguration
        let standard = FalseTouchProtection.standard.gestureConfiguration
        let light = FalseTouchProtection.light.gestureConfiguration
        XCTAssertEqual(strong.leftEntryStripWidth, 0.006)
        XCTAssertEqual(standard.leftEntryStripWidth, 0.008)
        XCTAssertEqual(light.leftEntryStripWidth, 0.010)
        XCTAssertEqual(strong.rightEntryStripWidth, 0.012)
        XCTAssertEqual(standard.rightEntryStripWidth, 0.015)
        XCTAssertEqual(light.rightEntryStripWidth, 0.019)

        // Hard safety rules must never drift between user-facing profiles.
        for configuration in [strong, standard, light] {
            XCTAssertEqual(configuration.entryCorridor, 0.03)
            XCTAssertEqual(configuration.controlCorridor, 0.08)
            XCTAssertEqual(configuration.minimumInwardTravel, 0.0)
            XCTAssertEqual(configuration.minimumVerticalMove, 0.015)
            XCTAssertEqual(configuration.outwardRejectionTravel, 0.004)
            XCTAssertEqual(configuration.directionalityRatio, 0.80)
            XCTAssertEqual(configuration.entryTimeout, 0.450)
            XCTAssertFalse(configuration.lowerHalfOnly)
        }
    }

    func testLegacySensitivityMigratesToNearestAdjustmentSpeed() {
        XCTAssertEqual(
            AdjustmentSpeed.migrated(fromLegacySensitivity: 0.30),
            .precise
        )
        XCTAssertEqual(
            AdjustmentSpeed.migrated(fromLegacySensitivity: 0.50),
            .precise
        )
        XCTAssertEqual(
            AdjustmentSpeed.migrated(fromLegacySensitivity: 0.58),
            .precise
        )
        XCTAssertEqual(
            AdjustmentSpeed.migrated(fromLegacySensitivity: 0.70),
            .standard
        )
        XCTAssertEqual(
            AdjustmentSpeed.migrated(fromLegacySensitivity: 0.75),
            .standard
        )
        XCTAssertEqual(
            AdjustmentSpeed.migrated(fromLegacySensitivity: 1.00),
            .fast
        )
        XCTAssertEqual(
            AdjustmentSpeed.migrated(fromLegacySensitivity: 1.65),
            .fast
        )
    }

    func testPersistedLegacySensitivityMigratesWhenNewKeyIsAbsent() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        defaults.set(1.65, forKey: "sensitivity")
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.adjustmentSpeed, .fast)
        XCTAssertEqual(settings.falseTouchProtection, .standard)
    }

    func testInvalidLegacyAndUnknownPresetValuesFallBackToDefaults() {
        XCTAssertEqual(
            AdjustmentSpeed.migrated(fromLegacySensitivity: .nan),
            .standard
        )

        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("future-speed", forKey: "adjustmentSpeed")
        defaults.set("future-protection", forKey: "falseTouchProtection")
        defaults.set(2.0, forKey: "sensitivity")

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.adjustmentSpeed, .standard)
        XCTAssertEqual(settings.falseTouchProtection, .standard)
    }

    func testTypingProtectionFailsOpenForInvalidElapsedTimeAndInterval() {
        var elapsed = -1.0
        let guardLogic = RecentKeyboardActivityGuard { elapsed }

        XCTAssertFalse(guardLogic.shouldBlock(for: 0.350))
        elapsed = .infinity
        XCTAssertFalse(guardLogic.shouldBlock(for: 0.600))
        elapsed = .nan
        XCTAssertFalse(guardLogic.shouldBlock(for: 0.200))
        elapsed = 0.0
        XCTAssertFalse(guardLogic.shouldBlock(for: 0.0))
        XCTAssertFalse(guardLogic.shouldBlock(for: .nan))
    }

    func testTrackpadPreferenceDefaultsToAutomatic() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        XCTAssertEqual(AppSettings(defaults: defaults).trackpadPreference, .automatic)
    }

    func testUnknownTrackpadPreferenceFallsBackToAutomatic() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("future-value", forKey: "trackpadPreference")

        XCTAssertEqual(AppSettings(defaults: defaults).trackpadPreference, .automatic)
    }

    func testExternalTrackpadShapeGuardRejectsPortraitAndInvalidSurfaces() {
        XCTAssertTrue(TrackpadManager.surfaceDimensionsLookLikeTrackpad(width: 13_000, height: 10_000))
        XCTAssertFalse(TrackpadManager.surfaceDimensionsLookLikeTrackpad(width: 5_152, height: 9_056))
        XCTAssertFalse(TrackpadManager.surfaceDimensionsLookLikeTrackpad(width: 0, height: 10_000))
        XCTAssertFalse(TrackpadManager.surfaceDimensionsLookLikeTrackpad(width: 10_000, height: 10_000))
    }

    func testExternalDDCToggleThroughAppModelPersists() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = AppSettings(defaults: defaults)
        let model = EdgeControlAppModel(settings: settings)
        model.setExternalDDCEnabled(true)

        XCTAssertTrue(settings.externalDDCEnabled)
        XCTAssertTrue(AppSettings(defaults: defaults).externalDDCEnabled)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let name = "EdgeControlTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }
}

@MainActor
final class BrightnessRoutingTests: XCTestCase {
    func testMissingExternalNeverProducesAnImplicitDDCError() {
        let builtIn = FakeBrightnessBackend(isAvailable: false, value: 0.4)
        let external = FakeExternalBrightnessBackend(isAvailable: true, value: 0.8)
        external.enabled = false
        let controller = DisplayBrightnessController(builtIn: builtIn, external: external)

        XCTAssertThrowsError(try controller.beginSession()) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Built-in display brightness control is temporarily unavailable."
            )
        }
        XCTAssertEqual(external.readCount, 0)
        XCTAssertEqual(external.writeCount, 0)

        external.enabled = true
        external.isAvailable = false
        XCTAssertThrowsError(try controller.beginSession()) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Built-in display brightness control is temporarily unavailable."
            )
        }
        XCTAssertEqual(external.readCount, 0)
        XCTAssertEqual(external.writeCount, 0)
    }

    func testBuiltInRefreshRecoversBeforeExternalFallback() throws {
        let builtIn = FakeBrightnessBackend(isAvailable: false, value: 0.42)
        builtIn.onRefresh = { builtIn.isAvailable = true }
        let external = FakeExternalBrightnessBackend(isAvailable: true, value: 0.9)
        external.enabled = true
        let controller = DisplayBrightnessController(builtIn: builtIn, external: external)

        let session = try controller.beginSession()

        XCTAssertEqual(session.initialValue, 0.42, accuracy: 0.000_001)
        XCTAssertEqual(builtIn.refreshCount, 1)
        XCTAssertEqual(builtIn.readCount, 1)
        XCTAssertEqual(external.readCount, 0)
    }

    func testEnabledAvailableExternalFallbackCanBeSelected() throws {
        let builtIn = FakeBrightnessBackend(isAvailable: false, value: 0.1)
        let external = FakeExternalBrightnessBackend(isAvailable: true, value: 0.7)
        external.enabled = true
        let controller = DisplayBrightnessController(builtIn: builtIn, external: external)

        let session = try controller.beginSession()
        try session.setBrightness(0.6)

        XCTAssertEqual(session.initialValue, 0.7, accuracy: 0.000_001)
        XCTAssertEqual(external.readCount, 1)
        XCTAssertEqual(external.writeCount, 1)
        XCTAssertEqual(external.value, 0.6, accuracy: 0.000_001)
    }

    func testBrightnessSessionDoesNotSwitchBackendsMidGesture() throws {
        let builtIn = FakeBrightnessBackend(isAvailable: true, value: 0.3)
        let external = FakeExternalBrightnessBackend(isAvailable: true, value: 0.8)
        external.enabled = true
        let controller = DisplayBrightnessController(builtIn: builtIn, external: external)

        let session = try controller.beginSession()
        builtIn.isAvailable = false
        try session.setBrightness(0.55)

        XCTAssertEqual(builtIn.writeCount, 1)
        XCTAssertEqual(builtIn.value, 0.55, accuracy: 0.000_001)
        XCTAssertEqual(external.writeCount, 0)
    }

    func testBuiltInDisplayRefreshRetainsOnlyAcrossQueryFailure() {
        var activeDisplays: [CGDirectDisplayID]? = [42]
        let backend = BuiltInDisplayBackend(
            activeDisplayProvider: { activeDisplays },
            builtInDetector: { $0 == 42 }
        )
        XCTAssertEqual(backend.displayID, 42)

        activeDisplays = nil
        backend.refresh()
        XCTAssertEqual(backend.displayID, 42)

        activeDisplays = [77]
        backend.refresh()
        XCTAssertNil(backend.displayID)
    }
}

@MainActor
private class FakeBrightnessBackend: BrightnessBackend {
    var isAvailable: Bool
    var value: Double
    var onRefresh: (() -> Void)?
    private(set) var refreshCount = 0
    private(set) var readCount = 0
    private(set) var writeCount = 0

    init(isAvailable: Bool, value: Double) {
        self.isAvailable = isAvailable
        self.value = value
    }

    func refresh() {
        refreshCount += 1
        onRefresh?()
    }

    func getBrightness() throws -> Double {
        readCount += 1
        return value
    }

    func setBrightness(_ value: Double) throws {
        writeCount += 1
        self.value = value
    }
}

@MainActor
private final class FakeExternalBrightnessBackend:
    FakeBrightnessBackend,
    ExternalBrightnessBackend
{
    var enabled = false
}
