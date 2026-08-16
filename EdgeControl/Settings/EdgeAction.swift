import Foundation

enum EdgeAction: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case disabled
    case volume
    case brightness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled: return "Off"
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        }
    }

    var systemImage: String {
        switch self {
        case .disabled: return "nosign"
        case .volume: return "speaker.wave.2.fill"
        case .brightness: return "sun.max.fill"
        }
    }
}
