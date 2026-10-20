import AppKit
import Combine

/// Sumber kebenaran tunggal untuk semua pengaturan aplikasi.
/// Semua nilai disimpan otomatis lewat UserDefaults setiap kali berubah,
/// jadi tetap tersimpan setelah aplikasi ditutup-buka lagi.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private enum Kunci {
        static let visualizerAktif = "visualizerAktif"
        static let tema = "temaWarna"
        static let warnaBebas = "warnaBebas"
        static let sensitivitas = "sensitivitas"
        static let jumlahBatang = "jumlahBatang"
        static let kecepatanAnimasi = "kecepatanAnimasi"
        static let doronganTrebel = "doronganTrebel"
        static let teksStandby = "teksStandby"
        static let sumberAudio = "sumberAudio"
        static let jalankanSaatLogin = "jalankanSaatLogin"
    }

    @Published var visualizerAktif: Bool {
        didSet { defaults.set(visualizerAktif, forKey: Kunci.visualizerAktif) }
    }

    @Published var tema: TemaWarna {
        didSet { defaults.set(tema.rawValue, forKey: Kunci.tema) }
    }

    /// Warna yang dipilih lewat color picker saat tema == .bebas.
    @Published var warnaBebas: NSColor {
        didSet { defaults.set(warnaBebas.hexString, forKey: Kunci.warnaBebas) }
    }

    /// 0.0 - 1.0
    @Published var sensitivitas: Double {
        didSet { defaults.set(sensitivitas, forKey: Kunci.sensitivitas) }
    }

    @Published var jumlahBatang: Int {
        didSet { defaults.set(jumlahBatang, forKey: Kunci.jumlahBatang) }
    }

    /// 0.0 - 1.0, makin besar makin cepat responsif (smoothing lebih kecil).
    @Published var kecepatanAnimasi: Double {
        didSet { defaults.set(kecepatanAnimasi, forKey: Kunci.kecepatanAnimasi) }
    }

    /// 0.0 - 1.0, seberapa kuat batang nada tinggi (treble) dikuatkan
    /// relatif ke bass, supaya tidak cuma bass yang keliatan gerak.
    @Published var doronganTrebel: Double {
        didSet { defaults.set(doronganTrebel, forKey: Kunci.doronganTrebel) }
    }

    /// Teks (boleh ada emoji) yang ditampilkan di Touch Bar sebagai pengganti
    /// batang visualizer, saat audio senyap 3 detik berturut-turut. Kosong =
    /// mode standby tidak aktif, Touch Bar tetap tampilkan batang diam.
    @Published var teksStandby: String {
        didSet { defaults.set(teksStandby, forKey: Kunci.teksStandby) }
    }

    @Published var sumberAudio: SumberAudio {
        didSet { defaults.set(sumberAudio.rawValue, forKey: Kunci.sumberAudio) }
    }

    @Published var jalankanSaatLogin: Bool {
        didSet {
            defaults.set(jalankanSaatLogin, forKey: Kunci.jalankanSaatLogin)
            LoginItemManager.shared.terapkan(aktif: jalankanSaatLogin)
        }
    }

    private init() {
        defaults.register(defaults: [
            Kunci.visualizerAktif: true,
            Kunci.tema: TemaWarna.neon.rawValue,
            Kunci.warnaBebas: "#facc15",
            Kunci.sensitivitas: 0.7,
            Kunci.jumlahBatang: 40,
            Kunci.kecepatanAnimasi: 0.6,
            Kunci.doronganTrebel: 0.0,
            Kunci.teksStandby: "",
            Kunci.sumberAudio: SumberAudio.mikrofon.rawValue,
            Kunci.jalankanSaatLogin: false
        ])

        visualizerAktif = defaults.bool(forKey: Kunci.visualizerAktif)
        tema = TemaWarna(rawValue: defaults.string(forKey: Kunci.tema) ?? "") ?? .neon
        warnaBebas = NSColor(hex: defaults.string(forKey: Kunci.warnaBebas) ?? "#facc15")
        sensitivitas = defaults.double(forKey: Kunci.sensitivitas)
        jumlahBatang = defaults.integer(forKey: Kunci.jumlahBatang)
        kecepatanAnimasi = defaults.double(forKey: Kunci.kecepatanAnimasi)
        doronganTrebel = defaults.double(forKey: Kunci.doronganTrebel)
        teksStandby = defaults.string(forKey: Kunci.teksStandby) ?? ""
        sumberAudio = SumberAudio(rawValue: defaults.string(forKey: Kunci.sumberAudio) ?? "") ?? .mikrofon
        jalankanSaatLogin = defaults.bool(forKey: Kunci.jalankanSaatLogin)
    }

    /// Warna gradient aktif saat ini (kiri -> kanan), sudah memperhitungkan tema bebas.
    var warnaGradientAktif: (awal: NSColor, akhir: NSColor) {
        tema.warnaGradientBawaan ?? (warnaBebas, warnaBebas)
    }
}
