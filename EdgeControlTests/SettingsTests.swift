import AppKit
import CoreAudio
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
