import Foundation

@MainActor
protocol BrightnessBackend: AnyObject {
    var isAvailable: Bool { get }
    func refresh()
    func getBrightness() throws -> Double
    func setBrightness(_ value: Double) throws
}

@MainActor
protocol ExternalBrightnessBackend: BrightnessBackend {
    var enabled: Bool { get set }
}
