import AppKit
import Combine
import ObjectiveC

// MARK: - Deklarasi API privat Apple

/// Tanda tangan fungsi C privat dari framework privat DFRFoundation, dimuat
/// manual lewat dlopen/dlsym karena tidak ada framework untuk di-link
/// langsung (tidak ada .tbd/.dylib publik untuk DFRFoundation).
private typealias DFRSetPresenceFunc = @convention(c) (NSTouchBarItem.Identifier, Bool) -> Void

private func dbg(_ pesan: String) {
    FileHandle.standardError.write("DEBUG[TouchBar]: \(pesan)\n".data(using: .utf8)!)
}

private extension NSTouchBarItem.Identifier {
    static let systemTrayVisualizer = NSTouchBarItem.Identifier("com.pribadi.VisualizerTouchBar.systemTray")
    static let visualizerBar = NSTouchBarItem.Identifier("com.pribadi.VisualizerTouchBar.bar")
    static let tombolWarna = NSTouchBarItem.Identifier("com.pribadi.VisualizerTouchBar.warna")
    static let tombolPower = NSTouchBarItem.Identifier("com.pribadi.VisualizerTouchBar.power")
}

/// Mengelola tampilan visualizer di Touch Bar, termasuk mempresentasikannya
/// sebagai Touch Bar modal yang menggantikan tampilan Touch Bar normal
/// macOS SAAT APLIKASI LAIN AKTIF — mirip cara kerja aplikasi seperti Pock.
///
/// ============================================================
/// PERINGATAN — API PRIVAT APPLE, BISA RUSAK SETELAH UPDATE macOS
/// ============================================================
/// Bagian ini memakai hal-hal yang TIDAK didokumentasikan resmi oleh Apple:
/// 1. `+[NSTouchBar presentSystemModalTouchBar:placement:
///    systemTrayItemIdentifier:]` / `+[NSTouchBar dismissSystemModalTouchBar:]`
///    — method CLASS privat di `NSTouchBar` (BUKAN di `NSApplication` —
///    sempat salah asumsi awal, lihat catatan di bawah), dipanggil lewat
///    `class_getClassMethod` + `method_getImplementation` (Objective-C
///    runtime langsung), BUKAN lewat `unsafeBitCast(NSTouchBar.self, to:
///    AnyObject.self)` + `perform(_:with:)` — itu yang bikin SEGFAULT diam-diam
///    (lihat catatan di CLAUDE.md & `kirimPesanKelasNSTouchBar` di bawah).
/// 2. `DFRElementSetControlStripPresenceForIdentifier` — fungsi C privat
///    dari DFRFoundation.framework, dimuat lewat dlopen/dlsym.
/// 3. `+[NSTouchBarItem addSystemTrayItem:]` / `+[NSTouchBarItem
///    removeSystemTrayItem:]` — method class privat (tidak ada di header
///    publik `NSTouchBarItem.h` versi SDK ini), dipanggil dengan teknik
///    runtime yang sama.
///
/// Riwayat: di versi macOS lama, `presentSystemModalTouchBar:placement:
/// systemTrayItemIdentifier:` ada sebagai INSTANCE method di NSApplication,
/// jadi awalnya dipanggil lewat cast NSApp ke @objc protocol privat. Di
/// macOS 26.6.2 (mesin ini), method itu ternyata sudah DIPINDAH Apple jadi
/// CLASS method di NSTouchBar — assert `NSApp.responds(to:)` jadi `false`
/// dan visualizer tidak pernah muncul di Touch Bar fisik walau tidak ada
/// crash/error (dipanggil lewat optional chaining `as?` yang diam-diam jadi
/// nil). Ketemu lewat scan `class_copyMethodList` langsung di runtime — kalau
/// visualizer tiba-tiba tidak muncul lagi setelah update macOS berikutnya,
/// scan ulang dengan cara yang sama duluan sebelum menebak-nebak nama method.
final class TouchBarController: NSObject {
    static let shared = TouchBarController()

    private let settings = SettingsStore.shared
    private var touchBarUtama: NSTouchBar?
    private var trayItem: NSCustomTouchBarItem?
    private var pelanggan = Set<AnyCancellable>()
    private var pelangganWarna: AnyCancellable?
    private let dfrSetPresence: DFRSetPresenceFunc?

    private override init() {
        self.dfrSetPresence = Self.muatDFRSetPresence()
        super.init()
    }

    private static func muatDFRSetPresence() -> DFRSetPresenceFunc? {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation",
            RTLD_NOW
        ) else { return nil }
        guard let sym = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") else { return nil }
        return unsafeBitCast(sym, to: DFRSetPresenceFunc.self)
    }

    /// Panggil `+[NSTouchBarItem addSystemTrayItem:]` / `removeSystemTrayItem:`
    /// lewat Objective-C runtime langsung (`class_getClassMethod` +
    /// `method_getImplementation`), karena tidak ada header publik untuk
    /// method class privat ini di SDK yang dipakai.
    private static func kirimPesanKelasNSTouchBarItem(_ namaSelector: String, item: NSTouchBarItem) {
        typealias FungsiSatuArgumen = @convention(c) (AnyClass, Selector, NSTouchBarItem) -> Void

        let selector = NSSelectorFromString(namaSelector)
        guard let method = class_getClassMethod(NSTouchBarItem.self, selector) else {
            dbg("Method class \(namaSelector) tidak ditemukan di NSTouchBarItem — API ini mungkin sudah berubah/dihapus di versi macOS ini")
            return
        }
        let imp = method_getImplementation(method)
        let fungsi = unsafeBitCast(imp, to: FungsiSatuArgumen.self)
        fungsi(NSTouchBarItem.self, selector, item)
    }

    /// Panggil `+[NSTouchBar presentSystemModalTouchBar:placement:
    /// systemTrayItemIdentifier:]` lewat Objective-C runtime langsung.
    private static func panggilPresentSystemModalTouchBar(
        _ touchBar: NSTouchBar,
        placement: Int64,
        systemTrayItemIdentifier: NSTouchBarItem.Identifier?
    ) {
        typealias Fungsi = @convention(c) (AnyClass, Selector, NSTouchBar, Int64, NSTouchBarItem.Identifier?) -> Void

        let selector = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
        guard let method = class_getClassMethod(NSTouchBar.self, selector) else {
            dbg("Method class presentSystemModalTouchBar:placement:systemTrayItemIdentifier: tidak ditemukan di NSTouchBar — API ini mungkin sudah berubah/dihapus di versi macOS ini")
            return
        }
        let imp = method_getImplementation(method)
        let fungsi = unsafeBitCast(imp, to: Fungsi.self)
        fungsi(NSTouchBar.self, selector, touchBar, placement, systemTrayItemIdentifier)
    }

    /// Panggil `+[NSTouchBar dismissSystemModalTouchBar:]` lewat Objective-C
    /// runtime langsung.
    private static func panggilDismissSystemModalTouchBar(_ touchBar: NSTouchBar) {
        typealias Fungsi = @convention(c) (AnyClass, Selector, NSTouchBar) -> Void

        let selector = NSSelectorFromString("dismissSystemModalTouchBar:")
        guard let method = class_getClassMethod(NSTouchBar.self, selector) else {
            dbg("Method class dismissSystemModalTouchBar: tidak ditemukan di NSTouchBar — API ini mungkin sudah berubah/dihapus di versi macOS ini")
            return
        }
        let imp = method_getImplementation(method)
        let fungsi = unsafeBitCast(imp, to: Fungsi.self)
        fungsi(NSTouchBar.self, selector, touchBar)
    }

    /// Panggil sekali saat aplikasi selesai launching. Mulai memantau
    /// `visualizerAktif` dan langsung menyesuaikan tampilan Touch Bar,
    /// termasuk state awal yang dibaca dari UserDefaults.
    func mulai() {
        settings.$visualizerAktif
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] aktif in
                if aktif {
                    self?.tampilkan()
                } else {
                    self?.sembunyikan()
                }
            }
            .store(in: &pelanggan)
    }

    private func tampilkan() {
        daftarkanTrayItem()
        let touchBar = buatTouchBarUtama()
        touchBarUtama = touchBar
        Self.panggilPresentSystemModalTouchBar(
            touchBar, placement: 0, systemTrayItemIdentifier: .systemTrayVisualizer
        )
    }

    /// Menyembunyikan visualizer total (dipanggil saat toggle off): Touch
    /// Bar kembali ke tampilan normal macOS.
    private func sembunyikan() {
        tutupModal()
        batalkanTrayItem()
    }

    /// Menutup modal saja (dipanggil saat visualizer dimatikan lewat tombol
    /// power), tanpa mengubah tray item — tray item tetap ada supaya bisa
    /// dibuka lagi.
    private func tutupModal() {
        guard let touchBar = touchBarUtama else { return }
        Self.panggilDismissSystemModalTouchBar(touchBar)
        touchBarUtama = nil
    }

    private func daftarkanTrayItem() {
        guard trayItem == nil else { return }
        let item = NSCustomTouchBarItem(identifier: .systemTrayVisualizer)
        let ikon = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Visualizer Touch Bar") ?? NSImage()
        let tombol = NSButton(image: ikon, target: self, action: #selector(tombolTrayDitekan))
        item.view = tombol
        trayItem = item

        Self.kirimPesanKelasNSTouchBarItem("addSystemTrayItem:", item: item)
        dfrSetPresence?(.systemTrayVisualizer, true)
    }

    private func batalkanTrayItem() {
        guard let item = trayItem else { return }
        dfrSetPresence?(.systemTrayVisualizer, false)
        Self.kirimPesanKelasNSTouchBarItem("removeSystemTrayItem:", item: item)
        trayItem = nil
    }

    @objc private func tombolTrayDitekan() {
        guard settings.visualizerAktif else { return }
        if touchBarUtama == nil {
            let touchBar = buatTouchBarUtama()
            touchBarUtama = touchBar
        }
        guard let touchBar = touchBarUtama else { return }
        Self.panggilPresentSystemModalTouchBar(
            touchBar, placement: 0, systemTrayItemIdentifier: .systemTrayVisualizer
        )
    }

    private func buatTouchBarUtama() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.visualizerBar, .tombolWarna, .tombolPower]
        return touchBar
    }
}

extension TouchBarController: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .visualizerBar:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let view = VisualizerAtauStandbyView()
            view.translatesAutoresizingMaskIntoConstraints = false
            let gradient = settings.warnaGradientAktif
            view.warnaAwal = gradient.awal
            view.warnaAkhir = gradient.akhir
            view.widthAnchor.constraint(equalToConstant: 440).isActive = true
            item.view = view

            pelangganWarna = settings.$tema
                .combineLatest(settings.$warnaBebas)
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak view] _, _ in
                    guard let self, let view else { return }
                    let gradient = self.settings.warnaGradientAktif
                    view.warnaAwal = gradient.awal
                    view.warnaAkhir = gradient.akhir
                }
            return item

        case .tombolWarna:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let tombol = NSButton(title: "", target: self, action: #selector(tombolWarnaDitekan))
            tombol.bezelStyle = .circular
            tombol.bezelColor = settings.warnaGradientAktif.awal
            item.view = tombol
            return item

        case .tombolPower:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let ikon = NSImage(systemSymbolName: "power", accessibilityDescription: "Matikan visualizer") ?? NSImage()
            item.view = NSButton(image: ikon, target: self, action: #selector(tombolPowerDitekan))
            return item

        default:
            return nil
        }
    }

    @objc private func tombolWarnaDitekan() {
        SettingsWindowController.shared.tampilkan()
    }

    @objc private func tombolPowerDitekan() {
        settings.visualizerAktif = false
    }
}
