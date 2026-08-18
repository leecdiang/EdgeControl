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
        XCTAssertEqual(settings.hapticStrength, .standard)
        XCTAssertEqual(settings.hudColorStyle, .system)
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
        settings?.hapticStrength = .strong
        settings?.hudColorStyle = .aurora
        settings?.adjustmentSpeed = .fast
        settings?.falseTouchProtection = .strong
        settings?.leftEdgeAction = .disabled
        settings?.externalDDCEnabled = true
        settings?.trackpadPreference = .external
        settings = nil

        let restored = AppSettings(defaults: defaults)
        XCTAssertFalse(restored.masterEnabled)
        XCTAssertFalse(restored.hapticFeedback)
        XCTAssertEqual(restored.hapticStrength, .strong)
        XCTAssertEqual(restored.hudColorStyle, .aurora)
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

    func testUnknownHapticAndHUDStylesFallBackToDefaults() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("future-strength", forKey: "hapticStrength")
        defaults.set("future-palette", forKey: "hudColorStyle")

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.hapticStrength, .standard)
        XCTAssertEqual(settings.hudColorStyle, .system)
    }

    func testLegacyColorfulHUDMigratesToThreeLevelPalette() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "colorfulHUD")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.hudColorStyle, .classic)
        XCTAssertEqual(defaults.string(forKey: "hudColorStyle"), HUDColorStyle.classic.rawValue)
        XCTAssertNil(defaults.object(forKey: "colorfulHUD"))

        let (neutralDefaults, neutralName) = makeDefaults()
        defer { neutralDefaults.removePersistentDomain(forName: neutralName) }
        neutralDefaults.set(false, forKey: "colorfulHUD")

        let neutralSettings = AppSettings(defaults: neutralDefaults)
        XCTAssertEqual(neutralSettings.hudColorStyle, .system)
        XCTAssertEqual(
            neutralDefaults.string(forKey: "hudColorStyle"),
            HUDColorStyle.system.rawValue
        )
        XCTAssertNil(neutralDefaults.object(forKey: "colorfulHUD"))
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

    func testExternalDDCWritesBackToTheResponsiveConnection() {
        XCTAssertEqual(
            ExternalDDCBackend.resolvedConnectionIndex(
                lastResponsiveIndex: 1,
                connectionCount: 2
            ),
            1
        )
        XCTAssertEqual(
            ExternalDDCBackend.resolvedConnectionIndex(
                lastResponsiveIndex: nil,
                connectionCount: 2
            ),
            0
        )
        XCTAssertNil(
            ExternalDDCBackend.resolvedConnectionIndex(
                lastResponsiveIndex: 0,
                connectionCount: 0
            )
        )
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let name = "EdgeControlTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }
}

@MainActor
final class DDCParsingTests: XCTestCase {
    // Builds a standard DDC/CI Get VCP Feature reply (VCP 0x10):
    // [0x02, result, 0x10, type, mh, ml, sh, sl, checksum]
    // with the checksum byte chosen so the XOR of the 9 bytes is zero.
    private func makeReply(
        maximum: UInt16,
        current: UInt16,
        resultCode: UInt8 = 0x00,
        leading: [UInt8] = []
    ) -> [UInt8] {
        var bytes: [UInt8] = leading + [0x02, resultCode, 0x10, 0x00]
        bytes.append(UInt8(maximum >> 8))
        bytes.append(UInt8(maximum & 0xFF))
        bytes.append(UInt8(current >> 8))
        bytes.append(UInt8(current & 0xFF))
        let checksum = bytes.reduce(UInt8(0), ^)
        bytes.append(checksum)
        return bytes
    }

    func testParsesStandardReplyLayout() {
        let reply = makeReply(maximum: 100, current: 50)
        var current: UInt16 = 0
        var maximum: UInt16 = 0
        XCTAssertTrue(reply.withUnsafeBytes { buffer in
            ec_ddc_parse_vcp10_reply(buffer.baseAddress!, buffer.count, &current, &maximum)
        })
        XCTAssertEqual(maximum, 100)
        XCTAssertEqual(current, 50)
    }

    func testParsesReplyWithLeadingDestinationByte() {
        let reply = makeReply(maximum: 200, current: 75, leading: [0x6F])
        var current: UInt16 = 0
        var maximum: UInt16 = 0
        XCTAssertTrue(reply.withUnsafeBytes { buffer in
            ec_ddc_parse_vcp10_reply(buffer.baseAddress!, buffer.count, &current, &maximum)
        })
        XCTAssertEqual(maximum, 200)
        XCTAssertEqual(current, 75)
    }

    func testRejectsNonZeroResultCode() {
        // result 0x01 = unsupported op code
        let reply = makeReply(maximum: 100, current: 50, resultCode: 0x01)
        var current: UInt16 = 0
        var maximum: UInt16 = 0
        XCTAssertFalse(reply.withUnsafeBytes { buffer in
            ec_ddc_parse_vcp10_reply(buffer.baseAddress!, buffer.count, &current, &maximum)
        })
    }

    func testRejectsCorruptChecksum() {
        var reply = makeReply(maximum: 100, current: 50)
        reply[reply.count - 1] ^= 0x01 // flip one bit in the checksum byte
        var current: UInt16 = 0
        var maximum: UInt16 = 0
        XCTAssertFalse(reply.withUnsafeBytes { buffer in
            ec_ddc_parse_vcp10_reply(buffer.baseAddress!, buffer.count, &current, &maximum)
        })
    }

    func testRejectsWrongVCPCode() {
        // VCP 0x12 (contrast) instead of 0x10 must not be accepted as brightness.
        var reply = makeReply(maximum: 100, current: 50)
        reply[2] = 0x12
        // Recompute checksum over the mutated message.
        reply[reply.count - 1] = reply.dropLast().reduce(UInt8(0), ^)
        var current: UInt16 = 0
        var maximum: UInt16 = 0
        XCTAssertFalse(reply.withUnsafeBytes { buffer in
            ec_ddc_parse_vcp10_reply(buffer.baseAddress!, buffer.count, &current, &maximum)
        })
    }

    func testRejectsTruncatedReply() {
        let reply = Array(makeReply(maximum: 100, current: 50).prefix(5))
        var current: UInt16 = 0
        var maximum: UInt16 = 0
        XCTAssertFalse(reply.withUnsafeBytes { buffer in
            ec_ddc_parse_vcp10_reply(buffer.baseAddress!, buffer.count, &current, &maximum)
        })
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
