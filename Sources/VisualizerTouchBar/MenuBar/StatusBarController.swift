import AppKit

/// Ikon di menu bar (NSStatusItem) beserta menu dropdown-nya, sesuai mockup
/// "Menu bar@1x.png": toggle aktif, tema warna, sumber audio, jalankan saat
/// login, Pengaturan…, Keluar.
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private let settings = SettingsStore.shared
    private var statusItem: NSStatusItem!

    private override init() {
        super.init()
    }

    func mulai() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Visualizer Touch Bar")

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - Bangun ulang isi menu setiap kali akan dibuka

    private func bangunUlangMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let itemToggle = NSMenuItem()
        itemToggle.view = buatBarisToggle()
        menu.addItem(itemToggle)

        menu.addItem(buatHeader("Tema warna"))
        let itemTema = NSMenuItem()
        itemTema.view = buatBarisTema()
        menu.addItem(itemTema)

        menu.addItem(.separator())

        menu.addItem(buatHeader("Sumber audio"))
        menu.addItem(buatItemPilihan(judul: "Mikrofon", terpilih: settings.sumberAudio == .mikrofon) { [weak self] in
            self?.settings.sumberAudio = .mikrofon
        })
        menu.addItem(buatItemPilihan(judul: "Audio sistem", terpilih: settings.sumberAudio == .audioSistem) { [weak self] in
            self?.settings.sumberAudio = .audioSistem
        })

        menu.addItem(.separator())

        menu.addItem(buatItemPilihan(judul: "Jalankan saat login", terpilih: settings.jalankanSaatLogin) { [weak self] in
            guard let self else { return }
            self.settings.jalankanSaatLogin.toggle()
        })

        menu.addItem(.separator())

        let itemPengaturan = NSMenuItem(title: "Pengaturan…", action: #selector(bukaPengaturan), keyEquivalent: ",")
        itemPengaturan.target = self
        menu.addItem(itemPengaturan)

        let itemKeluar = NSMenuItem(title: "Keluar", action: #selector(keluar), keyEquivalent: "q")
        itemKeluar.target = self
        menu.addItem(itemKeluar)
    }

    private func buatHeader(_ judul: String) -> NSMenuItem {
        let item = NSMenuItem(title: judul, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func buatBarisToggle() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 28))

        let label = NSTextField(labelWithString: "Visualizer aktif")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false

        let toggle = NSSwitch()
        toggle.state = settings.visualizerAktif ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggleAktifDiubah(_:))
        toggle.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(toggle)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func buatBarisTema() -> NSView {
        let diameter: CGFloat = 24
        let spasi: CGFloat = 10
        let temaDitampilkan: [TemaWarna] = [.neon, .sunset, .lautan, .monokrom]
        let lebarTotal = CGFloat(temaDitampilkan.count + 1) * diameter + CGFloat(temaDitampilkan.count) * spasi
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 40))

        var x = (260 - lebarTotal) / 2
        for tema in temaDitampilkan {
            let dot = TemaDotView(frame: NSRect(x: x, y: (40 - diameter) / 2, width: diameter, height: diameter))
            if let gradient = tema.warnaGradientBawaan {
                dot.warnaAwal = gradient.awal
                dot.warnaAkhir = gradient.akhir
            }
            dot.terpilih = settings.tema == tema
            dot.aksi = { [weak self] in
                self?.settings.tema = tema
                self?.statusItem.menu?.cancelTracking()
            }
            container.addSubview(dot)
            x += diameter + spasi
        }

        let dotTambah = TemaDotView(frame: NSRect(x: x, y: (40 - diameter) / 2, width: diameter, height: diameter))
        dotTambah.tampilkanPlus = true
        dotTambah.aksi = { [weak self] in
            self?.bukaColorPanel()
        }
        container.addSubview(dotTambah)

        return container
    }

    private func buatItemPilihan(judul: String, terpilih: Bool, aksi: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem()
        let baris = BarisPilihMenu(judul: judul, terpilih: terpilih)
        baris.aksi = { [weak self] in
            aksi()
            self?.statusItem.menu?.cancelTracking()
        }
        item.view = baris
        return item
    }

    private func bukaColorPanel() {
        let panel = NSColorPanel.shared
        panel.color = settings.warnaBebas
        panel.showsAlpha = false
        NSColorPanelObserver.shared.mulaiAmati { [weak self] warnaBaru in
            self?.settings.warnaBebas = warnaBaru
            self?.settings.tema = .bebas
        }
        statusItem.menu?.cancelTracking()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleAktifDiubah(_ sender: NSSwitch) {
        settings.visualizerAktif = (sender.state == .on)
    }

    @objc private func bukaPengaturan() {
        SettingsWindowController.shared.tampilkan()
    }

    @objc private func keluar() {
        NSApp.terminate(nil)
    }
}

extension StatusBarController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        bangunUlangMenu(menu)
    }
}

// MARK: - Baris menu dengan checkmark di kanan (Sumber audio, Jalankan saat login)

private final class BarisPilihMenu: NSView {
    private let checkmark = NSImageView()
    var aksi: (() -> Void)?

    init(judul: String, terpilih: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 26))

        let label = NSTextField(labelWithString: judul)
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false

        checkmark.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        checkmark.contentTintColor = .controlAccentColor
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = !terpilih

        addSubview(label)
        addSubview(checkmark)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmark.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            checkmark.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        let gesture = NSClickGestureRecognizer(target: self, action: #selector(diklik))
        addGestureRecognizer(gesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) tidak dipakai")
    }

    @objc private func diklik() {
        aksi?()
    }
}

// MARK: - Dot tema warna bulat (dipakai di baris "Tema warna")

private final class TemaDotView: NSView {
    var warnaAwal: NSColor = .white
    var warnaAkhir: NSColor = .white
    var terpilih: Bool = false
    var tampilkanPlus: Bool = false
    var aksi: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let gesture = NSClickGestureRecognizer(target: self, action: #selector(diklik))
        addGestureRecognizer(gesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) tidak dipakai")
    }

    @objc private func diklik() {
        aksi?()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = CGPath(ellipseIn: rect, transform: nil)

        if tampilkanPlus {
            ctx.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
            ctx.setLineDash(phase: 0, lengths: [3, 3])
            ctx.setLineWidth(1.5)
            ctx.addPath(path)
            ctx.strokePath()

            let atribut: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.tertiaryLabelColor,
                .font: NSFont.systemFont(ofSize: 14, weight: .regular)
            ]
            let simbol = "+"
            let ukuran = simbol.size(withAttributes: atribut)
            let titik = NSPoint(x: bounds.midX - ukuran.width / 2, y: bounds.midY - ukuran.height / 2)
            simbol.draw(at: titik, withAttributes: atribut)
        } else {
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()

            let warnaAwalCG = (warnaAwal.usingColorSpace(.sRGB) ?? warnaAwal).cgColor
            let warnaAkhirCG = (warnaAkhir.usingColorSpace(.sRGB) ?? warnaAkhir).cgColor
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: [warnaAwalCG, warnaAkhirCG] as CFArray, locations: [0, 1]) {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.minX, y: rect.midY),
                    end: CGPoint(x: rect.maxX, y: rect.midY),
                    options: []
                )
            }
            ctx.restoreGState()

            if terpilih {
                ctx.setStrokeColor(NSColor.white.cgColor)
                ctx.setLineWidth(2)
                ctx.addPath(CGPath(ellipseIn: bounds.insetBy(dx: 0.5, dy: 0.5), transform: nil))
                ctx.strokePath()
            }
        }
    }
}
