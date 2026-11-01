import Foundation
final class MemoryDefaults: UserDefaults {
    override func set(_ value: Any?, forKey key: String) {
        var domain = volatileDomain(forName: UserDefaults.argumentDomain)
        domain[key] = value
        setVolatileDomain(domain, forName: UserDefaults.argumentDomain)
    }
    override func set(_ value: Bool, forKey key: String) { set(value as Any, forKey: key) }
    override func removeObject(forKey key: String) {
        var domain = volatileDomain(forName: UserDefaults.argumentDomain)
        domain.removeValue(forKey: key)
        setVolatileDomain(domain, forName: UserDefaults.argumentDomain)
    }
}
func frame(_ y: Double, _ time: Double) -> TouchFrame {
    TouchFrame(contacts: [TouchContact(id: 1, x: 0.001, y: y, timestamp: time, phase: .moved)], timestamp: time)
}
@MainActor func runReview() {
    let defaults = MemoryDefaults(suiteName: "EdgeControl.Review." + UUID().uuidString)!
    // Volatile-only settings: never modify the user's app preferences.
    defaults.setVolatileDomain(["masterEnabled":true], forName: UserDefaults.argumentDomain)
    let settings = AppSettings(defaults: defaults)
    let model = EdgeControlAppModel(settings: settings, keyboardActivityGuard: RecentKeyboardActivityGuard { 999 })
    model.start()
    let t = ProcessInfo.processInfo.systemUptime
    model.consume(frame(0.5,t), generation: 0)
    model.consume(frame(0.53,t+0.02), generation: 0)
    precondition(model.reviewHasSession && model.reviewCursorFrozen)
    settings.masterEnabled = false
    for i in 1...120 { model.consume(frame(0.53,t+0.02+Double(i)*0.01), generation: 0) }
    print("MASTER_OFF: session=\(model.reviewHasSession) cursorFrozen=\(model.reviewCursorFrozen) after 120 stationary frames")
    precondition(model.reviewHasSession && model.reviewCursorFrozen)
    model.stop()
    // Fresh model, frames captured five seconds before consumption.
    let nextDefaults = MemoryDefaults(suiteName: "EdgeControl.Review." + UUID().uuidString)!
    nextDefaults.setVolatileDomain(["masterEnabled":true], forName: UserDefaults.argumentDomain)
    let nextSettings = AppSettings(defaults: nextDefaults)
    let next = EdgeControlAppModel(settings: nextSettings, keyboardActivityGuard: RecentKeyboardActivityGuard { 999 })
    next.start()
    VolumeController.writes = []
    let old = ProcessInfo.processInfo.systemUptime - 5
    next.consume(frame(0.5,old), generation: 0)
    next.consume(frame(0.53,old+0.02), generation: 0)
    next.consume(frame(0.56,old+0.04), generation: 0)
    print("STALE_FRAMES: age≈5s writes=\(VolumeController.writes) session=\(next.reviewHasSession)")
    precondition(VolumeController.writes.count == 1)
    next.stop()
}
MainActor.assumeIsolated { runReview() }
