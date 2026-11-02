import Foundation

@MainActor
protocol BrightnessBackend: AnyObject {
    var isAvailable: Bool { get }
    var targetDisplayID: UInt32? { get }
    func refresh()
    func getBrightness() throws -> Double
    func setBrightness(_ value: Double) throws
}

@MainActor
protocol ExternalBrightnessBackend: BrightnessBackend {
    var enabled: Bool { get set }
}

extension BrightnessBackend {
    var targetDisplayID: UInt32? { nil }
}
