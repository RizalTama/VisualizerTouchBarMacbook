import AppKit
import Combine

/// NSView yang menggambar batang visualizer dengan gradient horizontal.
/// Dipakai baik di dalam NSTouchBar maupun di pratinjau SwiftUI (lewat
/// NSViewRepresentable di `PratinjauVisualizerView`).
final class VisualizerBarView: NSView {
    var level: [Float] = [] {
        didSet { needsDisplay = true }
    }

    var warnaAwal: NSColor = NSColor(hex: "#22d3ee") {
        didSet { needsDisplay = true }
    }

    var warnaAkhir: NSColor = NSColor(hex: "#e879f9") {
        didSet { needsDisplay = true }
    }

    /// Proporsi lebar tiap "unit" batang yang jadi batang solid (sisanya
    /// jadi jarak antar-batang). Batang selalu mengisi penuh `bounds.width`
    /// (dari tepi kiri sampai tepi kanan), lebarnya dihitung otomatis dari
    /// bounds.width dibagi jumlah batang — bukan ukuran tetap — supaya
    /// jumlah batang berapa pun selalu memenuhi container-nya.
    var rasioIsi: CGFloat = 0.62

    private var pelanggan: AnyCancellable?

    /// Mulai memantau level langsung dari VisualizerEngine.
    func pantauEngine() {
        pelanggan = VisualizerEngine.shared.$levelTerbaru
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.level = level
            }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        guard !level.isEmpty else { return }

        let jumlah = level.count
        let totalLebarSatuan = bounds.width / CGFloat(jumlah)
        let lebarBatang = max(1, totalLebarSatuan * rasioIsi)
        let tinggiMaksimum = bounds.height
        let tinggiMinimum: CGFloat = 2

        for (i, nilai) in level.enumerated() {
            let x = CGFloat(i) * totalLebarSatuan + (totalLebarSatuan - lebarBatang) / 2
            let tinggi = max(tinggiMinimum, CGFloat(nilai) * tinggiMaksimum)
            let y = (bounds.height - tinggi) / 2
            let rect = NSRect(x: x, y: y, width: lebarBatang, height: tinggi)
            let path = NSBezierPath(roundedRect: rect, xRadius: lebarBatang / 2, yRadius: lebarBatang / 2)

            let t = jumlah > 1 ? CGFloat(i) / CGFloat(jumlah - 1) : 0
            let warna = interpolasi(warnaAwal, warnaAkhir, t)

            ctx.saveGState()
            path.addClip()
            ctx.setFillColor(warna.cgColor)
            ctx.fill(rect)
            ctx.restoreGState()
        }
    }

    private func interpolasi(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
        let aSRGB = a.usingColorSpace(.sRGB) ?? a
        let bSRGB = b.usingColorSpace(.sRGB) ?? b
        let r = aSRGB.redComponent + (bSRGB.redComponent - aSRGB.redComponent) * t
        let g = aSRGB.greenComponent + (bSRGB.greenComponent - aSRGB.greenComponent) * t
        let bl = aSRGB.blueComponent + (bSRGB.blueComponent - aSRGB.blueComponent) * t
        return NSColor(srgbRed: r, green: g, blue: bl, alpha: 1)
    }
}
