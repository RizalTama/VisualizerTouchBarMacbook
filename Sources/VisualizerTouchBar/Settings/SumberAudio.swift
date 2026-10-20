import Foundation

/// Sumber audio yang dianalisis untuk visualizer.
enum SumberAudio: String, CaseIterable, Codable, Identifiable {
    case mikrofon
    case audioSistem

    var id: String { rawValue }

    var namaTampilan: String {
        switch self {
        case .mikrofon: return "Mikrofon"
        case .audioSistem: return "Audio sistem"
        }
    }
}
