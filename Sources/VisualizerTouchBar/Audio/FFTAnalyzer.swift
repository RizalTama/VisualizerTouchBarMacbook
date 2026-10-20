import Accelerate

/// Melakukan FFT real-to-complex ukuran tetap memakai vDSP, menghasilkan
/// spektrum magnitude dari sekumpulan sampel audio time-domain.
final class FFTAnalyzer {
    let ukuranFFT: Int
    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private var window: [Float]

    init(ukuranFFT: Int = 1024) {
        precondition(ukuranFFT.nonzeroBitCount == 1, "ukuranFFT harus pangkat dua")
        self.ukuranFFT = ukuranFFT
        self.log2n = vDSP_Length(log2(Float(ukuranFFT)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Gagal membuat FFT setup")
        }
        self.setup = setup
        self.window = [Float](repeating: 0, count: ukuranFFT)
        vDSP_hann_window(&window, vDSP_Length(ukuranFFT), Int32(vDSP_HANN_NORM))
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
    }

    /// `sampel` idealnya berjumlah tepat `ukuranFFT` (kelebihan dipotong dari
    /// akhir, kekurangan diisi nol). Hasil: array magnitude sepanjang
    /// `ukuranFFT / 2`, urut dari frekuensi rendah ke tinggi.
    func magnitudeSpektrum(dari sampel: [Float]) -> [Float] {
        var sampelTerpotong = sampel
        if sampelTerpotong.count < ukuranFFT {
            sampelTerpotong += [Float](repeating: 0, count: ukuranFFT - sampelTerpotong.count)
        } else if sampelTerpotong.count > ukuranFFT {
            sampelTerpotong = Array(sampelTerpotong.suffix(ukuranFFT))
        }

        var sampelBerjendela = [Float](repeating: 0, count: ukuranFFT)
        vDSP_vmul(sampelTerpotong, 1, window, 1, &sampelBerjendela, 1, vDSP_Length(ukuranFFT))

        var realp = [Float](repeating: 0, count: ukuranFFT / 2)
        var imagp = [Float](repeating: 0, count: ukuranFFT / 2)
        var magnitudes = [Float](repeating: 0, count: ukuranFFT / 2)

        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                sampelBerjendela.withUnsafeBufferPointer { sampelPtr in
                    sampelPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: ukuranFFT / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(ukuranFFT / 2))
                    }
                }

                vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(ukuranFFT / 2))
            }
        }

        var magnitudeAkar = [Float](repeating: 0, count: magnitudes.count)
        var jumlah = Int32(magnitudes.count)
        vvsqrtf(&magnitudeAkar, magnitudes, &jumlah)

        return magnitudeAkar
    }
}
