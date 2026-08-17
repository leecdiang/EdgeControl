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
        settings?.sensitivity = 1.65
        settings?.leftEdgeAction = .disabled
        settings?.externalDDCEnabled = true
        settings?.trackpadPreference = .external
        settings = nil

        let restored = AppSettings(defaults: defaults)
        XCTAssertFalse(restored.masterEnabled)
        XCTAssertFalse(restored.hapticFeedback)
        XCTAssertEqual(restored.sensitivity, 1.65, accuracy: 0.000_001)
        XCTAssertEqual(restored.leftEdgeAction, .disabled)
        XCTAssertTrue(restored.externalDDCEnabled)
        XCTAssertEqual(restored.trackpadPreference, .external)
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
