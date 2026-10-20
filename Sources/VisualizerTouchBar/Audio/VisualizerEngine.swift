import Combine
import CoreGraphics
import Foundation

/// Koordinator utama: memulai/menghentikan sumber audio yang sesuai
/// berdasarkan `SettingsStore`, memproses spektrum FFT menjadi level
/// per-batang, lalu menyiarkan hasilnya lewat `levelTerbaru`.
///
/// Saat `visualizerAktif == false`, semua capture dihentikan total (tap
/// mikrofon dilepas, stream ScreenCaptureKit dihentikan) supaya hemat
/// CPU/baterai dan indikator mikrofon di menu bar ikut hilang.
final class VisualizerEngine: ObservableObject {
    static let shared = VisualizerEngine()

    @Published private(set) var levelTerbaru: [Float] = []

    /// true kalau audio senyap (nyaris tidak ada suara) selama >= 3 detik
    /// berturut-turut — dipakai buat memicu mode standby (teks custom) di
    /// Touch Bar. Lihat `ambangSenyap`/`durasiSenyapUntukStandby`.
    @Published private(set) var modeStandby: Bool = false

    private let settings = SettingsStore.shared
    private let prosesor = BarLevelsProcessor()

    private var mikrofon: MicrophoneCapture?
    private var audioSistem: SystemAudioCapture?
    private var pelanggan = Set<AnyCancellable>()

    private var waktuMulaiSenyap: Date?
    private let ambangSenyap: Float = 0.01
    private let durasiSenyapUntukStandby: TimeInterval = 3

    private init() {
        settings.$visualizerAktif
            .combineLatest(settings.$sumberAudio)
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] aktif, _ in
                self?.perbaruiStatusEngine(aktif: aktif)
            }
            .store(in: &pelanggan)

        settings.$jumlahBatang
            .sink { [weak self] jumlah in
                guard let self, !self.settings.visualizerAktif else { return }
                self.levelTerbaru = [Float](repeating: 0, count: jumlah)
            }
            .store(in: &pelanggan)
    }

    private func perbaruiStatusEngine(aktif: Bool) {
        berhentiSemua()
        guard aktif else {
            levelTerbaru = [Float](repeating: 0, count: settings.jumlahBatang)
            return
        }

        switch settings.sumberAudio {
        case .mikrofon:
            mulaiMikrofon()
        case .audioSistem:
            mulaiAudioSistem()
        }
    }

    private func mulaiMikrofon() {
        let mic = MicrophoneCapture()
        mic.onSpektrum = { [weak self] spektrum in
            self?.terimaSpektrum(spektrum)
        }
        mic.mintaIzinMikrofon { diizinkan in
            guard diizinkan else { return }
            try? mic.mulai()
        }
        mikrofon = mic
    }

    private func mulaiAudioSistem() {
        let capture = SystemAudioCapture()
        capture.onSpektrum = { [weak self] spektrum in
            self?.terimaSpektrum(spektrum)
        }
        audioSistem = capture
        Task {
            let preflight = CGPreflightScreenCaptureAccess()
            FileHandle.standardError.write("DEBUG CGPreflightScreenCaptureAccess()=\(preflight)\n".data(using: .utf8)!)
            do {
                try await capture.mulai()
                FileHandle.standardError.write("DEBUG audioSistem.mulai() SUKSES\n".data(using: .utf8)!)
            } catch {
                FileHandle.standardError.write("DEBUG audioSistem.mulai() GAGAL: \(error)\n".data(using: .utf8)!)
            }
        }
    }

    private func terimaSpektrum(_ spektrum: [Float]) {
        // Dipanggil di main thread oleh MicrophoneCapture/SystemAudioCapture.
        perbaruiDeteksiSenyap(spektrum: spektrum)
        levelTerbaru = prosesor.proses(
            spektrum: spektrum,
            jumlahBatang: settings.jumlahBatang,
            sensitivitas: settings.sensitivitas,
            kecepatanAnimasi: settings.kecepatanAnimasi,
            doronganTrebel: settings.doronganTrebel
        )
    }

    /// Lacak berapa lama audio sudah senyap berturut-turut. Dicek dari
    /// spektrum MENTAH (sebelum auto-gain `BarLevelsProcessor`), karena
    /// auto-gain menormalkan segalanya jadi relatif — nilai mentah yang
    /// masih mencerminkan "beneran senyap atau tidak" secara absolut.
    private func perbaruiDeteksiSenyap(spektrum: [Float]) {
        let rataMentah = spektrum.reduce(0, +) / Float(max(spektrum.count, 1))
        guard rataMentah < ambangSenyap else {
            waktuMulaiSenyap = nil
            modeStandby = false
            return
        }
        let mulai = waktuMulaiSenyap ?? Date()
        waktuMulaiSenyap = mulai
        if Date().timeIntervalSince(mulai) >= durasiSenyapUntukStandby {
            modeStandby = true
        }
    }

    private func berhentiSemua() {
        mikrofon?.berhenti()
        mikrofon = nil
        audioSistem?.berhenti()
        audioSistem = nil
        waktuMulaiSenyap = nil
        modeStandby = false
    }
}
