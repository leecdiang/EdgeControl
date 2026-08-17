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
