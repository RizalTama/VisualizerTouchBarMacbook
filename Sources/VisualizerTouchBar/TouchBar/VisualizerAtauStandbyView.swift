import AppKit
import Combine

/// Container yang otomatis beralih antara batang visualizer dan teks
/// standby custom (mis. "Rizal ♥️ Tika"), saat `VisualizerEngine` mendeteksi
/// audio senyap 3 detik berturut-turut dan teks standby diisi di Pengaturan.
/// Dipakai baik di Touch Bar maupun di Pratinjau jendela Pengaturan.
final class VisualizerAtauStandbyView: NSView {
    private let barView = VisualizerBarView()
    private let labelStandby = NSTextField(labelWithString: "")
    private var pelanggan = Set<AnyCancellable>()
    private let settings = SettingsStore.shared

    init() {
        super.init(frame: .zero)

        barView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(barView)

        labelStandby.translatesAutoresizingMaskIntoConstraints = false
        labelStandby.font = .systemFont(ofSize: 16, weight: .semibold)
        labelStandby.alignment = .center
        labelStandby.isHidden = true
        addSubview(labelStandby)

        NSLayoutConstraint.activate([
            barView.leadingAnchor.constraint(equalTo: leadingAnchor),
            barView.trailingAnchor.constraint(equalTo: trailingAnchor),
            barView.topAnchor.constraint(equalTo: topAnchor),
            barView.bottomAnchor.constraint(equalTo: bottomAnchor),
            labelStandby.leadingAnchor.constraint(equalTo: leadingAnchor),
            labelStandby.trailingAnchor.constraint(equalTo: trailingAnchor),
            labelStandby.topAnchor.constraint(equalTo: topAnchor),
            labelStandby.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        barView.pantauEngine()

        VisualizerEngine.shared.$modeStandby
            .combineLatest(settings.$teksStandby)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] standby, teks in
                self?.perbarui(standby: standby, teks: teks)
            }
            .store(in: &pelanggan)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) tidak dipakai")
    }

    var warnaAwal: NSColor {
        get { barView.warnaAwal }
        set {
            barView.warnaAwal = newValue
            labelStandby.textColor = newValue
        }
    }

    var warnaAkhir: NSColor {
        get { barView.warnaAkhir }
        set { barView.warnaAkhir = newValue }
    }

    var rasioIsi: CGFloat {
        get { barView.rasioIsi }
        set { barView.rasioIsi = newValue }
    }

    private func perbarui(standby: Bool, teks: String) {
        let teksBersih = teks.trimmingCharacters(in: .whitespacesAndNewlines)
        let tampilkanStandby = standby && !teksBersih.isEmpty
        labelStandby.stringValue = teksBersih
        labelStandby.isHidden = !tampilkanStandby
        barView.isHidden = tampilkanStandby
    }
}
