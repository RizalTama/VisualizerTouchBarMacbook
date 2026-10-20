import ScreenCaptureKit
import AVFoundation

/// Menangkap audio sistem (apa yang sedang diputar di seluruh Mac) lewat
/// ScreenCaptureKit (macOS 13+). Ini menangkap SEMUA audio sistem, bukan
/// per-aplikasi, dan butuh izin "Screen Recording" di System Settings
/// (audio sistem terikat ke izin capture layar di ScreenCaptureKit).
///
/// Catatan: untuk macOS lama yang tidak mendukung capture audio lewat
/// ScreenCaptureKit, alternatifnya adalah driver virtual seperti BlackHole
/// yang dipasang sebagai perangkat output lalu direkam sebagai input biasa
/// lewat AVAudioEngine — belum diimplementasikan di sini (lihat bagian
/// "Catatan/kendala" di CLAUDE.md).
final class SystemAudioCapture: NSObject {
    private var stream: SCStream?
    private let analyzer = FFTAnalyzer(ukuranFFT: 1024)
    private var bufferTertampung: [Float] = []
    private let antrianBuffer = DispatchQueue(label: "com.pribadi.VisualizerTouchBar.audiosistem")
    private let antrianSampel = DispatchQueue(label: "com.pribadi.VisualizerTouchBar.audiosistem.sck")

    var onSpektrum: (([Float]) -> Void)?

    func mulai() async throws {
        let konten = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = konten.displays.first else {
            throw NSError(
                domain: "SystemAudioCapture",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Tidak ada display ditemukan untuk ScreenCaptureKit"]
            )
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let konfigurasi = SCStreamConfiguration()
        konfigurasi.capturesAudio = true
        konfigurasi.excludesCurrentProcessAudio = true
        konfigurasi.width = 2
        konfigurasi.height = 2
        konfigurasi.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let streamBaru = SCStream(filter: filter, configuration: konfigurasi, delegate: nil)
        try streamBaru.addStreamOutput(self, type: .audio, sampleHandlerQueue: antrianSampel)
        try await streamBaru.startCapture()
        self.stream = streamBaru
    }

    func berhenti() {
        let streamLama = stream
        stream = nil
        Task {
            try? await streamLama?.stopCapture()
        }
        antrianBuffer.async { [weak self] in
            self?.bufferTertampung.removeAll()
        }
    }

    private func sampelFloat(dari sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let blockBuffer = sampleBuffer.dataBuffer else { return nil }

        var panjang = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &panjang, dataPointerOut: &dataPointer
        )
        guard status == kCMBlockBufferNoErr, let dataPointer else { return nil }

        guard let formatDescription = sampleBuffer.formatDescription,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        guard asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 else {
            // Format bukan Float32 — jarang terjadi di ScreenCaptureKit, tidak ditangani.
            return nil
        }

        let jumlahSampel = panjang / MemoryLayout<Float>.size
        return dataPointer.withMemoryRebound(to: Float.self, capacity: jumlahSampel) { ptr in
            Array(UnsafeBufferPointer(start: ptr, count: jumlahSampel))
        }
    }
}

extension SystemAudioCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        guard let sampel = sampelFloat(dari: sampleBuffer) else { return }

        antrianBuffer.async { [weak self] in
            guard let self else { return }
            self.bufferTertampung.append(contentsOf: sampel)
            if self.bufferTertampung.count >= self.analyzer.ukuranFFT {
                let spektrum = self.analyzer.magnitudeSpektrum(dari: self.bufferTertampung)
                self.bufferTertampung.removeAll()
                DispatchQueue.main.async {
                    self.onSpektrum?(spektrum)
                }
            }
        }
    }
}
