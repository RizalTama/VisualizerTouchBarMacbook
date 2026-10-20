import Foundation

/// Mengubah spektrum FFT (bin linear) menjadi array level per-batang lewat
/// pengelompokan skala logaritmik (supaya nada rendah tidak menumpuk semua
/// di beberapa bin pertama), auto-gain per batang (supaya semua batang
/// kelihatan "hidup", bukan cuma bass), lalu menghaluskan animasi antar-frame.
final class BarLevelsProcessor {
    private var levelSebelumnya: [Float] = []

    /// Puncak energi terbaru per-batang (meluruh pelan-pelan), dipakai
    /// sebagai acuan normalisasi auto-gain per batang.
    private var puncakPerBatang: [Float] = []

    private let lantaiPuncak: Float = 0.015
    private let peluruhanPuncak: Float = 0.992

    /// - Parameters:
    ///   - spektrum: hasil `FFTAnalyzer.magnitudeSpektrum`.
    ///   - jumlahBatang: jumlah batang yang diinginkan.
    ///   - sensitivitas: 0...1, dipakai sebagai penguat linear.
    ///   - kecepatanAnimasi: 0...1, makin besar makin cepat responsif
    ///     (smoothing antar-frame makin kecil).
    ///   - doronganTrebel: -0.5...0.5, seberapa kuat batang nada tinggi
    ///     dikuatkan (positif) atau diredam (negatif) relatif ke bass
    ///     (0 = tanpa kompensasi sama sekali).
    func proses(spektrum: [Float], jumlahBatang: Int, sensitivitas: Double, kecepatanAnimasi: Double, doronganTrebel: Double) -> [Float] {
        guard jumlahBatang > 0, !spektrum.isEmpty else { return [] }

        if levelSebelumnya.count != jumlahBatang {
            levelSebelumnya = [Float](repeating: 0, count: jumlahBatang)
        }
        if puncakPerBatang.count != jumlahBatang {
            puncakPerBatang = [Float](repeating: lantaiPuncak, count: jumlahBatang)
        }

        let jumlahBin = spektrum.count
        var levelBaru = [Float](repeating: 0, count: jumlahBatang)

        let minLog = log10(2.0)
        let maxLog = log10(Double(jumlahBin))

        for i in 0..<jumlahBatang {
            let t0 = Double(i) / Double(jumlahBatang)
            let t1 = Double(i + 1) / Double(jumlahBatang)
            let awal = Int(pow(10, minLog + t0 * (maxLog - minLog)))
            let akhirMentah = Int(pow(10, minLog + t1 * (maxLog - minLog)))
            let batasAkhir = min(max(akhirMentah, awal + 1), jumlahBin)
            let batasAwal = min(awal, max(batasAkhir - 1, 0))

            guard batasAwal < batasAkhir else {
                levelBaru[i] = 0
                continue
            }

            var jumlah: Float = 0
            for b in batasAwal..<batasAkhir {
                jumlah += spektrum[b]
            }
            let rata = jumlah / Float(batasAkhir - batasAwal)

            // Kompensasi tilt spektrum: nada tinggi (index besar) secara
            // alami jauh lebih lemah energinya dibanding bass di kebanyakan
            // musik. Makin ke kanan (nada tinggi), makin dikuatkan/diredam
            // sesuai `doronganTrebel` (bisa negatif). Skala eksponensial
            // (pow basis 2) supaya bass (posisi 0) selalu tetap di 1x, dan
            // hasilnya selalu positif walau doronganTrebel negatif.
            let posisi = jumlahBatang > 1 ? Double(i) / Double(jumlahBatang - 1) : 0
            let kompensasi = Float(pow(2.0, posisi * doronganTrebel * 4.0))
            let energi = rata * kompensasi

            // Auto-gain PER BATANG: tiap batang melacak puncak energinya
            // sendiri (naik instan kalau nemu nilai baru lebih tinggi,
            // meluruh pelan-pelan kalau tidak), lalu dinormalisasi relatif
            // ke puncak itu sendiri — bukan ke skala absolut tetap. Ini
            // yang bikin SEMUA batang kelihatan bergerak penuh & "hidup"
            // (imersif), bukan cuma batang yang kebetulan energinya besar
            // (biasanya bass) yang kelihatan gerak sementara sisanya datar.
            puncakPerBatang[i] = max(energi, puncakPerBatang[i] * peluruhanPuncak)
            let puncakEfektif = max(puncakPerBatang[i], lantaiPuncak)
            let relatif = min(energi / puncakEfektif, 1.0)

            // Kurva akar (pangkat 0.6) supaya gerakan pelan tetap kelihatan
            // jelas, tidak cuma pas lagi puncak.
            let dinormalisasi = pow(relatif, Float(0.6))
            let gain = Float(0.4 + sensitivitas * 1.6)
            // tanh sebagai soft-limiter: mendekati batas atas melandai
            // halus (bukan kepotong rata/flat), jadi batang tetap kelihatan
            // "bernapas" walau lagi di puncaknya.
            levelBaru[i] = tanh(dinormalisasi * gain)
        }

        // Attack cepat (naik hampir instan) + release mengikuti slider
        // "kecepatan animasi" (turun lebih halus) — meniru equalizer musik
        // asli: nyentak naik pas ada suara, meluncur turun pelan-pelan,
        // bukan gerak lembek simetris naik-turun.
        let alphaTurun = Float(max(0.05, min(1.0, kecepatanAnimasi)))
        let alphaNaik = Float(max(alphaTurun, 0.7))
        for i in 0..<jumlahBatang {
            let alpha = levelBaru[i] >= levelSebelumnya[i] ? alphaNaik : alphaTurun
            levelSebelumnya[i] += (levelBaru[i] - levelSebelumnya[i]) * alpha
        }

        return levelSebelumnya
    }
}
