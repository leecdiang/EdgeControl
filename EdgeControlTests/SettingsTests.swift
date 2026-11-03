import AppKit
import CoreAudio
import CoreGraphics
import XCTest
import SwiftUI
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

    func testMorandiPaletteIsSelectableAndPersists() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(HUDColorStyle.morandi.rawValue, forKey: "hudColorStyle")

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.hudColorStyle, .morandi)
        XCTAssertEqual(defaults.string(forKey: "hudColorStyle"), "morandi")
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

    func testHUDContinuousUpdatesRemainOnePresentation() {
        var lifecycle = HUDPresentationLifecycle()
        let size = NSSize(width: 176, height: 72)

        let first = lifecycle.plan(size: size, screenID: 1)
        XCTAssertTrue(first.isNewPresentation)
        XCTAssertTrue(first.shouldResize)
        XCTAssertTrue(first.shouldPosition)
        XCTAssertTrue(first.shouldOrderFront)

        for _ in 0..<100 {
            let update = lifecycle.plan(size: size, screenID: 1)
            XCTAssertFalse(update.isNewPresentation)
            XCTAssertFalse(update.shouldResize)
            XCTAssertFalse(update.shouldPosition)
            XCTAssertFalse(update.shouldOrderFront)
        }

        XCTAssertEqual(lifecycle.presentCount, 1)
        XCTAssertEqual(lifecycle.updateCount, 100)
        lifecycle.markHidden()
        XCTAssertEqual(lifecycle.dismissCount, 1)
    }

    func testHUDPaletteComponentsCoverEveryStyleAndKind() {
        for style in HUDColorStyle.allCases {
            for kind in [HUDKind.volume, .brightness] {
                if style == .system {
                    XCTAssertNil(HUDPalette.accentComponents(style: style, kind: kind))
                } else {
                    XCTAssertNotNil(HUDPalette.accentComponents(style: style, kind: kind))
                }
            }
        }
        XCTAssertEqual(
            HUDPalette.accentComponents(style: .morandi, kind: .volume),
            HUDPalette.AccentComponents(red: 0.639, green: 0.757, blue: 0.871)
        )
    }

    func testSingleInstanceFirstAcquireSucceedsAndCompetingAcquireFails() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EdgeControlTests-\(UUID().uuidString)", isDirectory: true)
        let lockURL = directory.appendingPathComponent("instance.lock")
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = SingleInstanceCoordinator(
            lockURL: lockURL,
            bundleIdentifier: "org.edgecontrol.tests",
            retryBudget: 0
        )
        let second = SingleInstanceCoordinator(
            lockURL: lockURL,
            bundleIdentifier: "org.edgecontrol.tests",
            retryBudget: 0
        )

        XCTAssertEqual(first.acquire(), .primary)
        XCTAssertEqual(second.acquire(), .duplicate)
        first.release()
        XCTAssertEqual(second.acquire(), .primary)
        second.release()
    }

    func testSingleInstanceLockFileCanRemainWithoutOwnership() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EdgeControlTests-\(UUID().uuidString)", isDirectory: true)
        let lockURL = directory.appendingPathComponent("instance.lock")
        defer { try? FileManager.default.removeItem(at: directory) }
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: lockURL.path, contents: Data())

        let coordinator = SingleInstanceCoordinator(lockURL: lockURL, retryBudget: 0)
        XCTAssertEqual(coordinator.acquire(), .primary)
        coordinator.release()
    }

    func testSingleInstanceFilesystemErrorIsNotReportedAsDuplicate() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EdgeControlTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        FileManager.default.createFile(atPath: directory.path, contents: Data())

        let coordinator = SingleInstanceCoordinator(
            lockURL: directory.appendingPathComponent("instance.lock"),
            retryBudget: 0
        )
        guard case .failed(.directoryCreationFailed) = coordinator.acquire() else {
            return XCTFail("Expected a directory creation failure")
        }
    }

    func testVolumeSessionPinsDeviceAcrossDefaultSwitch() throws {
        let backend = FakeVolumeBackend(defaultDevice: 1, values: [1: 0.25, 2: 0.80])
        let session = try VolumeControlSession(backend: backend)
        backend.defaultDevice = 2

        try session.setVolume(0.40)
        try session.setVolume(0.55)

        XCTAssertEqual(session.pinnedDeviceID, 1)
        XCTAssertEqual(backend.writtenDevices, [1, 1])
        XCTAssertEqual(backend.values[2] ?? -1, 0.80, accuracy: 0.000_001)
    }

    func testVolumeSessionFailsWhenPinnedDeviceDisappears() throws {
        let backend = FakeVolumeBackend(defaultDevice: 1, values: [1: 0.25, 2: 0.80])
        let session = try VolumeControlSession(backend: backend)
        backend.available.remove(1)

        XCTAssertThrowsError(try session.setVolume(0.40)) { error in
            XCTAssertEqual(error as? ControlError, .unavailable("Pinned output device is unavailable."))
        }
        XCTAssertTrue(backend.writtenDevices.isEmpty)
    }

    func testNewVolumeSessionUsesNewDefaultDeviceAfterPreviousSessionEnds() throws {
        let backend = FakeVolumeBackend(defaultDevice: 1, values: [1: 0.25, 2: 0.80])
        _ = try VolumeControlSession(backend: backend)
        backend.defaultDevice = 2

        let next = try VolumeControlSession(backend: backend)
        XCTAssertEqual(next.pinnedDeviceID, 2)
        XCTAssertEqual(next.initialValue, 0.80, accuracy: 0.000_001)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let name = "EdgeControlTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }
}

private final class FakeVolumeBackend: VolumeBackend {
    var defaultDevice: AudioDeviceID
    var values: [AudioDeviceID: Double]
    var available: Set<AudioDeviceID>
    private(set) var writtenDevices: [AudioDeviceID] = []

    init(defaultDevice: AudioDeviceID, values: [AudioDeviceID: Double]) {
        self.defaultDevice = defaultDevice
        self.values = values
        self.available = Set(values.keys)
    }

    func currentOutputDevice() throws -> AudioDeviceID {
        defaultDevice
    }

    func readVolume(on device: AudioDeviceID) throws -> Double {
        guard available.contains(device), let value = values[device] else {
            throw ControlError.unavailable("Pinned output device is unavailable.")
        }
        return value
    }

    func writeVolume(_ value: Double, on device: AudioDeviceID) throws {
        guard available.contains(device), values[device] != nil else {
            throw ControlError.unavailable("Pinned output device is unavailable.")
        }
        values[device] = value
        writtenDevices.append(device)
    }
}

@MainActor
final class DDCParsingTests: XCTestCase {
    // Independent full wire fixture: 50% brightness, maximum 100.
    private let wire: [UInt8] = [0x6E, 0x88, 0x02, 0, 0x10, 0, 0, 0x64, 0, 0x32, 0xF2]
    private func parse(_ bytes: [UInt8]) -> Bool {
        var current: UInt16 = 0, maximum: UInt16 = 0
        return bytes.withUnsafeBufferPointer { ec_ddc_parse_vcp10_reply($0.baseAddress, $0.count, &current, &maximum) }
    }
    private func checksum(_ bytes: [UInt8]) -> [UInt8] {
        var result = bytes
        result[result.count - 1] = result.dropLast().reduce(UInt8(0x50), ^)
        return result
    }
    func testParsesStandardReplyLayout() {
        var current: UInt16 = 0, maximum: UInt16 = 0
        XCTAssertTrue(wire.withUnsafeBufferPointer { ec_ddc_parse_vcp10_reply($0.baseAddress, $0.count, &current, &maximum) })
        XCTAssertEqual(current, 50)
        XCTAssertEqual(maximum, 100)
    }
    func testRejectsLeadingGarbageRatherThanScanningForOpcode() {
        XCTAssertFalse(parse([0x6F] + wire))
    }
    func testRejectsNonZeroResultCode() {
        var reply = wire; reply[3] = 1
        XCTAssertFalse(parse(checksum(reply)))
    }
    func testRejectsCorruptChecksum() {
        var reply = wire; reply[10] = 0x44 // formerly accepted command-only XOR
        XCTAssertFalse(parse(reply))
    }
    func testRejectsWrongVCPCode() {
        var reply = wire; reply[4] = 0x12
        XCTAssertFalse(parse(checksum(reply)))
    }
    func testRejectsTruncatedReply() {
        for length in 0..<wire.count { XCTAssertFalse(parse(Array(wire.prefix(length)))) }
    }
    func testRejectsWrongSourceLengthAndType() {
        for (index, value) in [(0, UInt8(0x50)), (1, 0x89), (5, 1)] {
            var reply = wire; reply[index] = value
            XCTAssertFalse(parse(checksum(reply)))
        }
    }
    func testRejectsInvalidRangeWithoutOverwritingOutputs() {
        var reply = wire; reply[9] = 101
        reply = checksum(reply)
        var current: UInt16 = 23, maximum: UInt16 = 45
        XCTAssertFalse(reply.withUnsafeBufferPointer { ec_ddc_parse_vcp10_reply($0.baseAddress, $0.count, &current, &maximum) })
        XCTAssertEqual(current, 23); XCTAssertEqual(maximum, 45)
        reply[7] = 0
        XCTAssertFalse(parse(checksum(reply)))
    }
    func testParsesSixteenBitRangeAndPaddedBuffer() {
        var reply = wire
        reply[6] = 1; reply[7] = 0x90 // max 400
        reply[8] = 1; reply[9] = 0x2C // current 300
        reply = checksum(reply) + [0, 0, 0]
        var current: UInt16 = 0, maximum: UInt16 = 0
        XCTAssertTrue(reply.withUnsafeBufferPointer { ec_ddc_parse_vcp10_reply($0.baseAddress, $0.count, &current, &maximum) })
        XCTAssertEqual(current, 300); XCTAssertEqual(maximum, 400)
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
    func testBrightnessSessionDeduplicatesBothClampedEndpoints() throws {
        for endpoint in [0.0, 1.0] {
            let backend = FakeBrightnessBackend(isAvailable: true, value: 0.5)
            let controller = DisplayBrightnessController(builtIn: backend, external: FakeExternalBrightnessBackend(isAvailable: false, value: 0))
            let session = try controller.beginSession()
            for _ in 0..<120 { try session.setBrightness(endpoint) }
            XCTAssertEqual(backend.writeCount, 1)
            XCTAssertEqual(backend.value, endpoint)
            try session.setBrightness(0.5)
            XCTAssertEqual(backend.writeCount, 2)
        }
    }

    func testBrightnessSessionDeduplicatesAtFloatPrecision() throws {
        let backend = FakeBrightnessBackend(isAvailable: true, value: 0.3)
        let controller = DisplayBrightnessController(builtIn: backend, external: FakeExternalBrightnessBackend(isAvailable: false, value: 0))
        let session = try controller.beginSession()
        try session.setBrightness(0.5)
        try session.setBrightness(0.5 + 1e-10)
        XCTAssertEqual(backend.writeCount, 1)
        try session.setBrightness(0.501)
        XCTAssertEqual(backend.writeCount, 2)
    }

    func testBrightnessNewSessionDoesNotReuseWriteCache() throws {
        let backend = FakeBrightnessBackend(isAvailable: true, value: 0.3)
        let controller = DisplayBrightnessController(builtIn: backend, external: FakeExternalBrightnessBackend(isAvailable: false, value: 0))
        try controller.beginSession().setBrightness(0.5)
        backend.value = 0.2 // Another app or the keyboard changed brightness.
        let next = try controller.beginSession()
        XCTAssertEqual(next.initialValue, 0.2)
        try next.setBrightness(0.5)
        XCTAssertEqual(backend.writeCount, 2)
    }

    func testFailedBrightnessWriteDoesNotPoisonDeduplication() throws {
        let backend = FakeBrightnessBackend(isAvailable: true, value: 0.3)
        let controller = DisplayBrightnessController(builtIn: backend, external: FakeExternalBrightnessBackend(isAvailable: false, value: 0))
        let session = try controller.beginSession()
        backend.failWrites = true
        XCTAssertThrowsError(try session.setBrightness(0.6))
        backend.failWrites = false
        try session.setBrightness(0.6)
        XCTAssertEqual(backend.writeCount, 1)
    }

    func testBrightnessRejectsNonFiniteReadsAndWrites() throws {
        let backend = FakeBrightnessBackend(isAvailable: true, value: 0.3)
        let controller = DisplayBrightnessController(builtIn: backend, external: FakeExternalBrightnessBackend(isAvailable: false, value: 0))
        let session = try controller.beginSession()
        for invalid in [Double.nan, .infinity, -.infinity] {
            XCTAssertThrowsError(try session.setBrightness(invalid))
            backend.value = invalid
            XCTAssertThrowsError(try controller.beginSession())
        }
        XCTAssertEqual(backend.writeCount, 0)
    }

    func testSuccessfulEmptyDisplayEnumerationClearsBuiltIn() {
        let result = BuiltInDisplayBackend.activeDisplayIDs { _, _, count in
            count?.pointee = 0
            return .success
        }
        XCTAssertEqual(result, [])
        var displays: [CGDirectDisplayID]? = [42]
        let backend = BuiltInDisplayBackend(activeDisplayProvider: { displays }, builtInDetector: { $0 == 42 })
        displays = result
        backend.refresh()
        XCTAssertNil(backend.displayID)
    }

    func testDisplayEnumerationFailureAndShrinkingList() {
        XCTAssertNil(BuiltInDisplayBackend.activeDisplayIDs { _, _, _ in .failure })
        var calls = 0
        let result = BuiltInDisplayBackend.activeDisplayIDs { _, _, count in
            calls += 1
            count?.pointee = calls == 1 ? 1 : 0
            return .success
        }
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(result, [])
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
    var failWrites = false

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
        if failWrites { throw ControlError.writeFailed("Injected failure") }
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

private final class RecordingAudioTransport: AudioVolumeTransport {
    var elements: [AudioObjectPropertyElement] = [1, 2]
    var values: [AudioObjectPropertyElement: Float] = [1: 0.2, 2: 0.8]
    var writes: [(AudioObjectPropertyElement, Float)] = []
    var failedRead: AudioObjectPropertyElement?
    var failNextWrite: AudioObjectPropertyElement?
    var failAllWrites = false
    func currentOutputDevice() throws -> AudioDeviceID { 42 }
    func volumeElements(on device: AudioDeviceID, requireSettable: Bool) -> [AudioObjectPropertyElement] { elements }
    func readScalar(on device: AudioDeviceID, element: AudioObjectPropertyElement) throws -> Float {
        guard element != failedRead, let value = values[element] else { throw ControlError.readFailed("Injected read failure") }
        return value
    }
    func writeScalar(_ value: Float, on device: AudioDeviceID, element: AudioObjectPropertyElement) throws {
        if failAllWrites { throw ControlError.writeFailed("Injected persistent failure") }
        if element == failNextWrite {
            failNextWrite = nil
            throw ControlError.writeFailed("Injected write failure")
        }
        writes.append((element, value)); values[element] = value
    }
}

final class VolumeChannelTests: XCTestCase {
    func testSessionPreservesBalanceAcrossZeroAndFullScale() throws {
        let transport = RecordingAudioTransport()
        let session = try VolumeController(transport: transport).beginSession()
        XCTAssertEqual(session.initialValue, 0.8, accuracy: 1e-6)
        try session.setVolume(0.81)
        XCTAssertEqual(transport.values[1]!, 0.2025, accuracy: 1e-6)
        XCTAssertEqual(transport.values[2]!, 0.81, accuracy: 1e-6)
        try session.setVolume(0)
        try session.setVolume(1)
        XCTAssertEqual(transport.values[1]!, 0.25, accuracy: 1e-6)
        XCTAssertEqual(transport.values[2]!, 1, accuracy: 1e-6)
    }
    func testZeroChannelsStartWithNeutralBalance() throws {
        let transport = RecordingAudioTransport(); transport.values = [1: 0, 2: 0]
        try VolumeController(transport: transport).beginSession().setVolume(0.4)
        XCTAssertEqual(transport.values[1]!, 0.4, accuracy: 1e-6)
        XCTAssertEqual(transport.values[2]!, 0.4, accuracy: 1e-6)
    }
    func testMasterScalarUsesSingleChannel() throws {
        let transport = RecordingAudioTransport(); transport.elements = [0]; transport.values = [0: 0.6]
        try VolumeController(transport: transport).beginSession().setVolume(0.4)
        XCTAssertEqual(transport.writes.count, 1)
        XCTAssertEqual(transport.values[0]!, 0.4, accuracy: 1e-6)
    }
    func testPartialReadCannotCreateSessionOrWrite() {
        let transport = RecordingAudioTransport(); transport.failedRead = 2
        let controller = VolumeController(transport: transport)
        XCTAssertThrowsError(try controller.readVolume(on: 42))
        XCTAssertThrowsError(try controller.beginSession())
        XCTAssertTrue(transport.writes.isEmpty)
    }
    func testNonFiniteReadAndWriteNeverReachDevice() throws {
        for invalid in [Float.nan, .infinity, -.infinity] {
            let transport = RecordingAudioTransport(); transport.values[2] = invalid
            XCTAssertThrowsError(try VolumeController(transport: transport).beginSession())
            XCTAssertTrue(transport.writes.isEmpty)
        }
        let transport = RecordingAudioTransport()
        let controller = VolumeController(transport: transport)
        let session = try controller.beginSession()
        for invalid in [Double.nan, .infinity, -.infinity] {
            XCTAssertThrowsError(try session.setVolume(invalid))
            XCTAssertThrowsError(try controller.setVolume(invalid))
        }
        XCTAssertTrue(transport.writes.isEmpty)
    }
    func testNonFiniteBackendInitialValueIsRejected() {
        let backend = FakeVolumeBackend(defaultDevice: 1, values: [1: .nan])
        XCTAssertThrowsError(try VolumeControlSession(backend: backend))
        XCTAssertTrue(backend.writtenDevices.isEmpty)
    }
    func testReadFailureDuringSessionPreventsPartialWrite() throws {
        let transport = RecordingAudioTransport()
        let session = try VolumeController(transport: transport).beginSession()
        transport.failedRead = 2
        XCTAssertThrowsError(try session.setVolume(0.5))
        XCTAssertTrue(transport.writes.isEmpty)
    }
    func testPartialWriteRollsBackAndCanRetrySameTarget() throws {
        let transport = RecordingAudioTransport()
        let session = try VolumeController(transport: transport).beginSession()
        transport.failNextWrite = 2
        XCTAssertThrowsError(try session.setVolume(0.4))
        XCTAssertEqual(transport.values[1]!, 0.2, accuracy: 1e-6)
        XCTAssertEqual(transport.values[2]!, 0.8, accuracy: 1e-6)
        try session.setVolume(0.4)
        XCTAssertEqual(transport.values[1]!, 0.1, accuracy: 1e-6)
        XCTAssertEqual(transport.values[2]!, 0.4, accuracy: 1e-6)
    }
    func testRollbackFailureIsReported() throws {
        let transport = RecordingAudioTransport()
        let session = try VolumeController(transport: transport).beginSession()
        transport.failAllWrites = true
        XCTAssertThrowsError(try session.setVolume(0.4)) { error in
            XCTAssertTrue(error.localizedDescription.contains("restoration was incomplete"))
        }
    }
    func testChannelLayoutChangeFailsBeforeWriting() throws {
        let transport = RecordingAudioTransport()
        let session = try VolumeController(transport: transport).beginSession()
        transport.elements = [0]; transport.values[0] = 0.5
        XCTAssertThrowsError(try session.setVolume(0.4))
        XCTAssertTrue(transport.writes.isEmpty)
    }
    func testRepeatedEndpointWritesAreDeduplicatedPerSession() throws {
        let transport = RecordingAudioTransport()
        let controller = VolumeController(transport: transport)
        let session = try controller.beginSession()
        for _ in 0..<120 { try session.setVolume(1) }
        XCTAssertEqual(transport.writes.count, 2)
        try controller.beginSession().setVolume(1)
        XCTAssertEqual(transport.writes.count, 4)
    }
}

@MainActor
final class InputLifecycleTests: XCTestCase {
    private func frame(_ y: Double?, receipt: Double = 10, timestamp: Double = 1) -> TouchFrame {
        TouchFrame(contacts: y.map { [TouchContact(id: 1, x: 0.001, y: $0, timestamp: timestamp, phase: .moved)] } ?? [],
                   timestamp: timestamp, receivedAtUptime: receipt)
    }
    private func model() -> (EdgeControlAppModel, AppSettings, RecordingAudioTransport) {
        let name = "EdgeControlTests.Input." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        settings.showHUD = false; settings.hapticFeedback = false
        let transport = RecordingAudioTransport()
        let model = EdgeControlAppModel(settings: settings,
            keyboardActivityGuard: RecentKeyboardActivityGuard { 999 },
            volumeController: VolumeController(transport: transport),
            cursorController: CursorController(associate: { _ in .success }),
            updateController: UpdateController(startingUpdater: false), inputNow: { 10 })
        return (model, settings, transport)
    }
    private func activate(_ model: EdgeControlAppModel) {
        model.consume(frame(0.5), generation: 0)
        model.consume(frame(0.53, timestamp: 1.02), generation: 0)
        XCTAssertTrue(model.isControlling)
        XCTAssertTrue(model.isCursorFrozen)
    }
    func testMasterOffRestoresCursorWithoutNextMovementAndRequiresLift() {
        let (model, settings, transport) = model(); activate(model)
        settings.masterEnabled = false
        XCTAssertFalse(model.isControlling); XCTAssertFalse(model.isCursorFrozen)
        settings.masterEnabled = true
        model.consume(frame(0.56, timestamp: 1.04), generation: 0)
        XCTAssertTrue(transport.writes.isEmpty); XCTAssertFalse(model.isControlling)
        model.consume(frame(nil), generation: 0)
        activate(model)
    }
    func testDisabledActionAndEdgeReassignmentEndSessionImmediately() {
        let (model, settings, _) = model(); activate(model)
        settings.volumeEnabled = false
        XCTAssertFalse(model.isControlling); XCTAssertFalse(model.isCursorFrozen)
        model.consume(frame(nil), generation: 0); settings.volumeEnabled = true
        activate(model)
        settings.leftEdgeAction = .disabled
        XCTAssertFalse(model.isControlling); XCTAssertFalse(model.isCursorFrozen)
    }
    func testPausedBirthCannotActivateWhenReenabledBeforeLift() {
        let (model, settings, _) = model()
        settings.masterEnabled = false
        model.consume(frame(0.5), generation: 0)
        settings.masterEnabled = true
        model.consume(frame(0.53, timestamp: 1.02), generation: 0)
        XCTAssertFalse(model.isControlling)
        model.consume(frame(nil), generation: 0); activate(model)
    }
    func testOldReceiptCancelsSessionWithoutWriting() {
        let (model, _, transport) = model(); activate(model)
        model.consume(frame(0.56, receipt: 5, timestamp: 1.04), generation: 0)
        XCTAssertFalse(model.isControlling); XCTAssertFalse(model.isCursorFrozen)
        XCTAssertTrue(transport.writes.isEmpty)
        model.consume(frame(0.58, timestamp: 1.06), generation: 0)
        XCTAssertFalse(model.isControlling)
        model.consume(frame(nil), generation: 0); activate(model)
    }
    func testOldAndInvalidReceiptCannotStartGestureOrClearLiftLatch() {
        for receipt in [5.0, Double.nan, .infinity, 11] {
            let (model, _, transport) = model()
            model.consume(frame(0.5, receipt: receipt), generation: 0)
            model.consume(frame(nil, receipt: 5), generation: 0)
            model.consume(frame(0.53, timestamp: 1.02), generation: 0)
            XCTAssertFalse(model.isControlling); XCTAssertTrue(transport.writes.isEmpty)
            model.consume(frame(nil), generation: 0); activate(model)
        }
    }
    func testFreshReceiptDoesNotAssumeDeviceClockEqualsUptime() {
        let (model, _, transport) = model(); activate(model)
        model.consume(frame(0.56, timestamp: 1.04), generation: 0)
        XCTAssertEqual(transport.writes.count, 2)
    }
    func testOverflowCancelsAndRequiresFreshLift() {
        let (model, _, transport) = model(); activate(model)
        model.consume(frame(0.56, timestamp: 1.04), generation: 0, discontinuity: true)
        XCTAssertFalse(model.isControlling); XCTAssertFalse(model.isCursorFrozen)
        XCTAssertTrue(transport.writes.isEmpty)
        model.consume(frame(nil), generation: 0); activate(model)
    }
    func testStoppedGenerationCannotBeResurrectedByQueuedFrames() {
        let (model, _, transport) = model(); activate(model); model.stop()
        model.consume(frame(nil), generation: 0)
        model.consume(frame(0.5), generation: 0)
        model.consume(frame(0.53, timestamp: 1.02), generation: 0)
        model.consume(frame(0.56, timestamp: 1.04), generation: 0)
        XCTAssertFalse(model.isControlling); XCTAssertFalse(model.isCursorFrozen)
        XCTAssertTrue(transport.writes.isEmpty)
    }
    func testMailboxPreservesOrderAndSchedulesOneConsumer() {
        let mailbox = TouchFrameMailbox(capacity: 3)
        XCTAssertTrue(mailbox.submit(frame(0.5, timestamp: 1)))
        XCTAssertFalse(mailbox.submit(frame(nil, timestamp: 2)))
        XCTAssertEqual(mailbox.next()?.frame.timestamp, 1)
        XCTAssertEqual(mailbox.next()?.frame.timestamp, 2)
        XCTAssertNil(mailbox.next())
        XCTAssertTrue(mailbox.submit(frame(0.5, timestamp: 3)))
    }
    func testMailboxOverflowFlagsDiscontinuityAndRetainsLift() {
        let mailbox = TouchFrameMailbox(capacity: 2)
        _ = mailbox.submit(frame(0.5, timestamp: 1))
        _ = mailbox.submit(frame(0.53, timestamp: 2))
        _ = mailbox.submit(frame(0.56, timestamp: 3))
        _ = mailbox.submit(frame(nil, timestamp: 4))
        let first = mailbox.next()
        XCTAssertEqual(first?.frame.timestamp, 3); XCTAssertEqual(first?.discontinuity, true)
        let lift = mailbox.next()
        XCTAssertEqual(lift?.frame.contacts.count, 0); XCTAssertEqual(lift?.discontinuity, false)
        XCTAssertNil(mailbox.next())
    }
}

final class AdaptiveHUDGeometryTests: XCTestCase {
    private func screen(x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 1512,
                        height: CGFloat = 982, notch: CGFloat = 32, gap: CGFloat = 180) -> HUDScreenGeometry {
        let frame = NSRect(x: x, y: y, width: width, height: height)
        return HUDScreenGeometry(frame: frame,
            visibleFrame: NSRect(x: x, y: y + 40, width: width, height: height - 40 - max(notch, 24)),
            safeTop: notch,
            leftArea: notch > 0 ? NSRect(x: x, y: frame.maxY - notch, width: (width - gap) / 2, height: notch) : nil,
            rightArea: notch > 0 ? NSRect(x: x + (width + gap) / 2, y: frame.maxY - notch, width: (width - gap) / 2, height: notch) : nil)
    }
    func testNotchWingsReservePhysicalCutoutWithoutAddingHeight() {
        let s = screen()
        let p = HUDPlacement.resolve(mode: .notch, screen: s)
        XCTAssertTrue(p.attachedToNotch)
        XCTAssertEqual(p.frame.maxY, s.frame.maxY)
        XCTAssertEqual(p.cutoutHeight, 32)
        XCTAssertEqual(p.frame.midX, s.frame.midX)
        XCTAssertEqual(p.frame.height - p.cutoutHeight - 16, 0)
        XCTAssertEqual(p.cutoutWidth, 180)
        XCTAssertEqual(p.contentWidth, 356)
    }
    func testScaledNotchLayoutsUsePointsAtDifferentSizes() {
        for (width, height, notch, gap) in [(1280.0, 832.0, 28.0, 160.0), (1728, 1117, 37, 210), (2056, 1329, 43, 240)] {
            let s = screen(width: width, height: height, notch: notch, gap: gap)
            let p = HUDPlacement.resolve(mode: .notch, screen: s)
            XCTAssertEqual(p.cutoutHeight, notch)
            XCTAssertTrue(s.frame.contains(p.frame))
            XCTAssertEqual(p.contentWidth, gap + 176)
            XCTAssertEqual(p.cutoutWidth, gap)
            XCTAssertEqual(p.frame.height - p.cutoutHeight - 16, 0)
        }
    }
    func testNotchErrorUsesReadableCapsuleBelowCamera() {
        let s = screen()
        let p = HUDPlacement.resolve(mode: .notch, screen: s, error: true)
        XCTAssertFalse(p.attachedToNotch)
        XCTAssertEqual(p.contentWidth, 212)
        XCTAssertLessThan(p.frame.maxY, s.frame.maxY - s.safeTop)
        let hiddenMenu = HUDScreenGeometry(frame: s.frame, visibleFrame: s.frame,
            safeTop: s.safeTop, leftArea: s.leftArea, rightArea: s.rightArea)
        let hiddenPlacement = HUDPlacement.resolve(mode: .notch, screen: hiddenMenu, error: true)
        XCTAssertLessThan(hiddenPlacement.frame.maxY, s.frame.maxY - s.safeTop)
    }
    func testInsufficientWingRoomFallsBackInsteadOfMovingCameraGap() {
        let original = screen()
        let s = HUDScreenGeometry(frame: original.frame, visibleFrame: original.visibleFrame,
            safeTop: 32, leftArea: NSRect(x: 0, y: 950, width: 60, height: 32),
            rightArea: NSRect(x: 240, y: 950, width: 1272, height: 32))
        XCTAssertFalse(HUDPlacement.resolve(mode: .notch, screen: s).attachedToNotch)
    }
    func testOffCenterCutoutRemainsPreciselyAligned() {
        let original = screen(x: -1512)
        let s = HUDScreenGeometry(frame: original.frame, visibleFrame: original.visibleFrame,
            safeTop: 32, leftArea: NSRect(x: -1512, y: 950, width: 600, height: 32),
            rightArea: NSRect(x: -732, y: 950, width: 732, height: 32))
        let p = HUDPlacement.resolve(mode: .notch, screen: s)
        XCTAssertTrue(p.attachedToNotch)
        XCTAssertEqual(p.frame.midX, -822)
        XCTAssertEqual(p.cutoutWidth, 180)
    }
    func testTooShortMenuStripUsesReadableFallback() {
        XCTAssertFalse(HUDPlacement.resolve(mode: .notch, screen: screen(notch: 16)).attachedToNotch)
    }
    func testNotchlessExternalScreenFallsBackInsideVisibleTop() {
        let s = screen(width: 2560, height: 1440, notch: 0)
        let p = HUDPlacement.resolve(mode: .notch, screen: s)
        XCTAssertFalse(p.attachedToNotch)
        XCTAssertEqual(p.frame.maxY, s.visibleFrame.maxY - 8)
        XCTAssertTrue(s.visibleFrame.contains(p.frame))
    }
    func testNegativeOriginAndVerticallyStackedDisplays() {
        for s in [screen(x: -1920, y: -200, width: 1920, height: 1080, notch: 0), screen(x: 100, y: 982)] {
            let p = HUDPlacement.resolve(mode: .notch, screen: s)
            XCTAssertTrue(s.frame.contains(p.frame))
            XCTAssertEqual(p.frame.midX, s.frame.midX)
        }
    }
    func testPortraitDisplayUsesTopCapsule() {
        let s = screen(width: 1080, height: 1920, notch: 0)
        let p = HUDPlacement.resolve(mode: .notch, screen: s)
        XCTAssertFalse(p.attachedToNotch)
        XCTAssertTrue(s.visibleFrame.contains(p.frame))
    }
    func testMissingOrInvalidCutoutMetadataFallsBack() {
        let original = screen()
        for left in [nil, NSRect(x: 0, y: 950, width: 1300, height: 32)] {
            let s = HUDScreenGeometry(frame: original.frame, visibleFrame: original.visibleFrame,
                safeTop: 32, leftArea: left, rightArea: original.rightArea)
            let p = HUDPlacement.resolve(mode: .notch, screen: s)
            XCTAssertFalse(p.attachedToNotch)
            XCTAssertTrue(s.visibleFrame.contains(p.frame))
        }
    }
    func testCapsuleKeepsLowerPlacementOnNotchedScreen() {
        let s = screen()
        let p = HUDPlacement.resolve(mode: .capsule, screen: s)
        XCTAssertFalse(p.attachedToNotch)
        XCTAssertEqual(p.contentWidth, 144)
        XCTAssertEqual(p.frame.size, NSSize(width: 176, height: 72))
        XCTAssertEqual(p.frame.minY, s.visibleFrame.minY + s.visibleFrame.height * 0.16)
    }
    func testErrorWidthExpandsWithoutMovingOffscreen() {
        let s = screen(notch: 0)
        let p = HUDPlacement.resolve(mode: .notch, screen: s, error: true)
        XCTAssertEqual(p.contentWidth, 212)
        XCTAssertTrue(s.visibleFrame.contains(p.frame))
    }
    func testAutoHiddenMenuBarUsesUpdatedVisibleFrame() {
        let s = screen(notch: 0)
        let hidden = HUDScreenGeometry(frame: s.frame, visibleFrame: s.frame, safeTop: 0, leftArea: nil, rightArea: nil)
        XCTAssertNotEqual(HUDPlacement.resolve(mode: .notch, screen: s).frame,
                          HUDPlacement.resolve(mode: .notch, screen: hidden).frame)
    }
    func testBrightnessTargetOverridesPointerAndVolumeRemainsPinned() {
        XCTAssertEqual(HUDScreenSelection.resolve(available: [1, 2], preferred: 1, pinned: 2, pointer: 2), 1)
        XCTAssertEqual(HUDScreenSelection.resolve(available: [1, 2], preferred: nil, pinned: 1, pointer: 2), 1)
    }
    func testDisconnectedDisplayFallsBackToAvailableScreen() {
        XCTAssertEqual(HUDScreenSelection.resolve(available: [2], preferred: 1, pinned: 1, pointer: 2), 2)
        XCTAssertEqual(HUDScreenSelection.resolve(available: [2], preferred: 1, pinned: 1, pointer: nil), 2)
        XCTAssertNil(HUDScreenSelection.resolve(available: [], preferred: 1, pinned: 1, pointer: nil))
    }
}

@MainActor
final class FeedbackSettingsMigrationTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "EdgeControlTests.Feedback." + UUID().uuidString
        let d = UserDefaults(suiteName: name)!
        addTeardownBlock { d.removePersistentDomain(forName: name) }
        return d
    }
    func testLegacyHiddenHUDStaysHidden() {
        let d = defaults(); d.set(false, forKey: AppSettings.Key.showHUD)
        let settings = AppSettings(defaults: d)
        XCTAssertEqual(settings.hudMode, .off)
        XCTAssertFalse(settings.showHUD)
    }
    func testVisibleHUDDefaultsToCapsuleAndUnknownModeFallsBack() {
        let d = defaults(); d.set("future-style", forKey: AppSettings.Key.hudMode)
        let settings = AppSettings(defaults: d)
        XCTAssertEqual(settings.hudMode, .capsule)
    }
    func testNotchModeSurvivesQuickToggleAndRelaunch() {
        let d = defaults()
        let settings = AppSettings(defaults: d)
        settings.hudMode = .notch; settings.showHUD = false
        let restored = AppSettings(defaults: d)
        XCTAssertEqual(restored.hudMode, .off)
        restored.showHUD = true
        XCTAssertEqual(restored.hudMode, .notch)
        XCTAssertEqual(AppSettings(defaults: d).hudMode, .notch)
    }
    func testOldDisabledGlobalActionMigratesToDisabledEdgeOnce() {
        let d = defaults(); d.set(false, forKey: AppSettings.Key.volumeEnabled)
        let settings = AppSettings(defaults: d)
        XCTAssertEqual(settings.leftEdgeAction, .disabled)
        XCTAssertEqual(settings.rightEdgeAction, .brightness)
        XCTAssertTrue(settings.volumeEnabled)
        settings.leftEdgeAction = .volume
        XCTAssertEqual(AppSettings(defaults: d).leftEdgeAction, .volume)
    }
    func testTwoEdgesWithSameDisabledActionBothMigrate() {
        let d = defaults()
        d.set("volume", forKey: AppSettings.Key.rightEdgeAction)
        d.set(false, forKey: AppSettings.Key.volumeEnabled)
        let settings = AppSettings(defaults: d)
        XCTAssertEqual(settings.leftEdgeAction, .disabled)
        XCTAssertEqual(settings.rightEdgeAction, .disabled)
    }
}

@MainActor
final class NativeUISnapshotTests: XCTestCase {
    func testHUDValueBurstWaitsForInitialLayoutAndHideCancelsReveal() async throws {
        let controller = HUDController()
        defer { controller.hideImmediately() }
        for i in 0..<100 {
            controller.show(HUDPresentation(kind: .volume, value: Double(i) / 100, message: nil))
        }
        XCTAssertFalse(controller.debugIsPresented, "Values must not bypass the collapsed first frame")
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(controller.debugIsPresented)
        XCTAssertEqual(controller.debugMetrics.orderFrontCount, 1)
        controller.hideImmediately()
        controller.show(HUDPresentation(kind: .volume, value: 0.5, message: nil))
        controller.hideImmediately()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(controller.debugIsPresented, "A cancelled reveal must not bring back a hidden HUD")
    }

    func testHUDHeldGestureSurvivesPauseAndReversesRetractionInSameWindow() async throws {
        let controller = HUDController()
        defer { controller.hideImmediately() }
        controller.setMode(.notch)
        controller.beginGesture()
        controller.show(HUDPresentation(kind: .brightness, value: 0.4, message: nil))
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertTrue(controller.debugIsPresented, "A stationary finger must not dismiss an active gesture")
        controller.endGesture()
        try await Task.sleep(nanoseconds: 750_000_000)
        XCTAssertFalse(controller.debugIsPresented)
        controller.beginGesture()
        controller.show(HUDPresentation(kind: .brightness, value: 0.6, message: nil))
        XCTAssertTrue(controller.debugIsPresented)
        // Wait past the old orderOut deadline. Cancellation must keep the same
        // window alive and avoid restarting the reveal from a collapsed pose.
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertTrue(controller.debugIsPresented)
        XCTAssertEqual(controller.debugMetrics.presentCount, 1)
        XCTAssertEqual(controller.debugMetrics.orderFrontCount, 1)
        XCTAssertEqual(controller.debugMetrics.dismissCount, 0)
    }

    func testHUDPreviewAutoDismissesAndGestureEndPreservesErrorTimeout() async throws {
        let controller = HUDController()
        defer { controller.hideImmediately() }
        controller.show(HUDPresentation(kind: .volume, value: 0.5, message: nil))
        try await Task.sleep(nanoseconds: 750_000_000)
        XCTAssertFalse(controller.debugIsPresented, "A settings preview must still auto-dismiss")
        controller.beginGesture()
        controller.show(HUDPresentation(kind: .volume, value: nil, message: "Unavailable"))
        controller.endGesture()
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertTrue(controller.debugIsPresented, "Errors need the full readable timeout after lift")
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertFalse(controller.debugIsPresented)
    }

    func testNotchWingsKeepCameraClearAndRecoverFromInterruptedRetraction() throws {
        func content(_ shown: Bool, _ reduced: Bool = false) -> some View {
            EdgeHUDView(presentation: HUDPresentation(kind: .brightness, value: 0.62, message: nil),
                isPresented: shown, colorStyle: .system, cutoutHeight: 32,
                surfaceWidth: 356, cutoutWidth: 180, reduceMotionOverride: reduced)
                .background(Color.white)
        }
        let view = NSHostingView(rootView: content(false))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 388, height: 48),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .white
        window.contentView = view
        window.orderFrontRegardless()
        defer { window.close() }
        var frames: [NSImage] = []
        for (index, state) in [(false, 0.1), (true, 0.16), (true, 0.65),
                                (false, 0.10), (true, 0.65), (false, 0.65)].enumerated() {
            view.rootView = content(state.0)
            RunLoop.main.run(until: Date().addingTimeInterval(state.1))
            view.layoutSubtreeIfNeeded()
            let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: rep)
            let image = NSImage(size: view.bounds.size)
            image.addRepresentation(rep)
            frames.append(image)
            if index == 2 || index == 4 {
                // Camera occupies x=104...284. No text or progress may enter it.
                let scale = CGFloat(rep.pixelsWide) / 388
                for x in stride(from: 110, to: 278, by: 4) {
                    let c = try XCTUnwrap(rep.colorAt(x: Int(CGFloat(x) * scale), y: Int(16 * scale))?.usingColorSpace(.deviceRGB))
                    XCTAssertLessThan(max(c.redComponent, max(c.greenComponent, c.blueComponent)), 0.05)
                }
            }
            if index == 0 || index == 2 || index == 4 || index == 5 {
                let scale = CGFloat(rep.pixelsWide) / 388
                let wing = try XCTUnwrap(rep.colorAt(x: Int(45 * scale), y: Int(7 * scale))?.usingColorSpace(.deviceRGB))
                if index == 2 || index == 4 {
                    XCTAssertLessThan(wing.redComponent, 0.05, "Wings must re-expand after interrupted retraction")
                } else {
                    XCTAssertGreaterThan(wing.redComponent, 0.95, "Retracted wings must leave desktop clear")
                }
            }
        }
        view.rootView = content(false, true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        let hidden = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: hidden)
        let center = try XCTUnwrap(hidden.colorAt(x: hidden.pixelsWide / 2, y: hidden.pixelsHigh / 3)?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(center.redComponent, 0.95, "Reduce Motion hides without horizontal morphing")
        let sheet = NSImage(size: NSSize(width: 388, height: 48 * frames.count))
        sheet.lockFocus()
        for (i, frame) in frames.enumerated() {
            frame.draw(in: NSRect(x: 0, y: (frames.count - i - 1) * 48, width: 388, height: 48))
        }
        sheet.unlockFocus()
        let png = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(sheet.tiffRepresentation))?.representation(using: .png, properties: [:]))
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("build/UI-Snapshots")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appendingPathComponent("notch-transitions.png"))
        let encoded = png.base64EncodedString()
        for start in stride(from: 0, to: encoded.count, by: 4000) {
            print("EDGE_NOTCH_IMAGE_CHUNK:\(start):" + String(encoded.dropFirst(start).prefix(4000)))
        }
    }

    func testSettingsPagesAndHUDPreviewsRenderInBothAppearances() throws {
        let name = "EdgeControlTests.Snapshots." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        let model = EdgeControlAppModel(settings: settings, updateController: UpdateController(startingUpdater: false))
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/UI-Snapshots")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (label, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            for page in SettingsView.Page.allCases {
                let view = makeSettingsWindowContent(SettingsView(model: model, settings: settings, initialPage: page))
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 640),
                    styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: appearance)
                window.contentView = view
                window.orderFrontRegardless()
                view.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.2))
                view.displayIfNeeded()
                let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: rep)
                let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
                try data.write(to: directory.appendingPathComponent("settings-\(page.rawValue)-\(label).png"))
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
                attachment.name = "Settings \(page.rawValue) \(label)"
                attachment.lifetime = .keepAlways
                add(attachment)
                window.close()
            }
            let menuView = NSHostingView(rootView: MenuBarMenuView().environmentObject(model))
            let menuWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 304, height: 250),
                styleMask: [.borderless], backing: .buffered, defer: false)
            menuWindow.isReleasedWhenClosed = false
            menuWindow.appearance = NSAppearance(named: appearance)
            menuWindow.contentView = menuView
            menuWindow.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            menuView.layoutSubtreeIfNeeded()
            let menuRep = try XCTUnwrap(menuView.bitmapImageRepForCachingDisplay(in: menuView.bounds))
            menuView.cacheDisplay(in: menuView.bounds, to: menuRep)
            try XCTUnwrap(menuRep.representation(using: .png, properties: [:]))
                .write(to: directory.appendingPathComponent("menu-\(label).png"))
            menuWindow.close()
            for mode in [HUDMode.capsule, .notch, .off] {
                let view = NSHostingView(rootView: HUDStylePreview(mode: mode, style: .system).frame(width: 360, height: 140))
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 140),
                    styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: appearance)
                window.contentView = view
                window.orderFrontRegardless()
                RunLoop.main.run(until: Date().addingTimeInterval(0.2))
                view.layoutSubtreeIfNeeded()
                let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: rep)
                let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
                try data.write(to: directory.appendingPathComponent("hud-\(mode.rawValue)-\(label).png"))
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
                attachment.name = "HUD \(mode.rawValue) \(label)"
                attachment.lifetime = .keepAlways
                add(attachment)
                window.close()
            }
        }
        // Compact native rendering evidence, also retrievable through text-only
        // CI log tooling. Original PNGs remain in the artifact and xcresult.
        let sheet = NSImage(size: NSSize(width: 960, height: 1180))
        sheet.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(x: 0, y: 0, width: 960, height: 1180).fill()
        for (row, appearance) in ["light", "dark"].enumerated() {
            for (column, page) in SettingsView.Page.allCases.enumerated() {
                let image = try XCTUnwrap(NSImage(contentsOf: directory.appendingPathComponent("settings-\(page.rawValue)-\(appearance).png")))
                image.draw(in: NSRect(x: CGFloat(column * 320 + 5), y: CGFloat(1180 - (row + 1) * 320), width: 310, height: 320))
            }
        }
        for (row, appearance) in ["light", "dark"].enumerated() {
            for (column, mode) in HUDMode.allCases.enumerated() {
                let image = try XCTUnwrap(NSImage(contentsOf: directory.appendingPathComponent("hud-\(mode.rawValue)-\(appearance).png")))
                let x = CGFloat(column * 320), y = CGFloat(340 - row * 125)
                image.draw(in: NSRect(x: x, y: y, width: 320, height: 124))
                ("\(mode.title) · \(appearance)" as NSString).draw(at: NSPoint(x: x + 12, y: y + 4),
                    withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
            }
            let menu = try XCTUnwrap(NSImage(contentsOf: directory.appendingPathComponent("menu-\(appearance).png")))
            menu.draw(in: NSRect(x: CGFloat(row * 360 + 140), y: 8, width: 243, height: 200))
        }
        sheet.unlockFocus()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(sheet.tiffRepresentation)))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: directory.appendingPathComponent("contact-sheet.png"))
        let encoded = png.base64EncodedString()
        for start in stride(from: 0, to: encoded.count, by: 4000) {
            print("EDGE_UI_IMAGE_CHUNK:\(start):" + String(encoded.dropFirst(start).prefix(4000)))
        }
    }
}

@MainActor
private struct HUDPreviewSwitchHarness: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        HUDStylePreview(mode: settings.hudMode, style: .system).frame(width: 360, height: 140)
    }
}

@MainActor
final class HUDPreviewSwitchTests: XCTestCase {
    func testSwitchingModesInOneHostedViewNeverShowsPreviousShape() throws {
        let name = "EdgeControlTests.PreviewSwitch." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        let view = NSHostingView(rootView: HUDPreviewSwitchHarness(settings: settings).environment(\.colorScheme, .light))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 140),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .white
        window.contentView = view
        window.orderFrontRegardless()
        defer { window.close() }
        for mode in [HUDMode.capsule, .notch, .off, .capsule, .notch, .capsule] {
            settings.hudMode = mode
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            view.layoutSubtreeIfNeeded()
            let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: rep)
            var dark = 0, total = 0
            for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
                for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                    let c = try XCTUnwrap(rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                    if c.alphaComponent > 0.9 && max(c.redComponent, max(c.greenComponent, c.blueComponent)) < 0.2 { dark += 1 }
                    total += 1
                }
            }
            let fraction = Double(dark) / Double(total)
            if mode == .notch {
                XCTAssertGreaterThan(fraction, 0.08, "Notch must render its black attached silhouette")
            } else {
                XCTAssertLessThan(fraction, 0.04, "\(mode) must not retain the notch silhouette")
            }
        }
    }

    func testSettingsBackdropTracksWindowAppearance() throws {
        let view = makeSettingsWindowContent(Color.clear.frame(width: 100, height: 100))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        defer { window.close() }
        XCTAssertTrue(view.subviews.first is NSVisualEffectView)
        var values: [CGFloat] = []
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            window.appearance = NSAppearance(named: appearance)
            window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            let cg = try XCTUnwrap(view.subviews[1].layer?.backgroundColor)
            let c = try XCTUnwrap(NSColor(cgColor: cg)?.usingColorSpace(.deviceRGB))
            values.append(c.redComponent)
            XCTAssertEqual(c.alphaComponent, CGFloat(EdgeUITheme.settingsNeutralScrimOpacity), accuracy: 0.01)
        }
        XCTAssertGreaterThan(values[0], values[1])
    }
}
