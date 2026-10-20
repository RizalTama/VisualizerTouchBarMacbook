import AppKit

/// Tema warna gradient untuk batang visualizer.
enum TemaWarna: String, CaseIterable, Codable, Identifiable {
    case neon
    case sunset
    case lautan
    case monokrom
    case bebas

    var id: String { rawValue }

    var namaTampilan: String {
        switch self {
        case .neon: return "Neon"
        case .sunset: return "Sunset"
        case .lautan: return "Lautan"
        case .monokrom: return "Monokrom"
        case .bebas: return "Warna bebas"
        }
    }

    /// Warna gradient bawaan (kiri -> kanan). `nil` untuk `.bebas` karena
    /// warnanya diambil dari `SettingsStore.warnaBebas` (color picker).
    var warnaGradientBawaan: (awal: NSColor, akhir: NSColor)? {
        switch self {
        case .neon: return (NSColor(hex: "#22d3ee"), NSColor(hex: "#e879f9"))
        case .sunset: return (NSColor(hex: "#fb923c"), NSColor(hex: "#f43f5e"))
        case .lautan: return (NSColor(hex: "#2dd4bf"), NSColor(hex: "#3b82f6"))
        case .monokrom: return (NSColor(hex: "#a1a1aa"), NSColor(hex: "#fafafa"))
        case .bebas: return nil
        }
    }
}

extension NSColor {
    /// Inisialisasi dari string hex seperti "#22d3ee" atau "22d3ee".
    convenience init(hex: String) {
        let bersih = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var nilaiRGB: UInt64 = 0
        Scanner(string: bersih).scanHexInt64(&nilaiRGB)
        let r = CGFloat((nilaiRGB & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((nilaiRGB & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(nilaiRGB & 0x0000FF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    /// Representasi hex "#rrggbb", dipakai untuk disimpan ke UserDefaults.
    var hexString: String {
        guard let warnaSRGB = usingColorSpace(.sRGB) else { return "#facc15" }
        let r = Int(round(warnaSRGB.redComponent * 255))
        let g = Int(round(warnaSRGB.greenComponent * 255))
        let b = Int(round(warnaSRGB.blueComponent * 255))
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
