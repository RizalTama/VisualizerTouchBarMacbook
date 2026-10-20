import AppKit
import SwiftUI

/// Pembungkus SwiftUI untuk `VisualizerAtauStandbyView`, dipakai sebagai
/// pratinjau langsung di jendela Pengaturan (termasuk pratinjau mode
/// standby, biar bisa dites tanpa nunggu Touch Bar fisik).
struct PratinjauVisualizerView: NSViewRepresentable {
    var warnaAwal: NSColor
    var warnaAkhir: NSColor

    func makeNSView(context: Context) -> VisualizerAtauStandbyView {
        let view = VisualizerAtauStandbyView()
        view.warnaAwal = warnaAwal
        view.warnaAkhir = warnaAkhir
        return view
    }

    func updateNSView(_ nsView: VisualizerAtauStandbyView, context: Context) {
        nsView.warnaAwal = warnaAwal
        nsView.warnaAkhir = warnaAkhir
    }
}
