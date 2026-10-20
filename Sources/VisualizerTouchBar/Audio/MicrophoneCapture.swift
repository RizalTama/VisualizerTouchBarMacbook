import AVFoundation

/// Menangkap audio dari mikrofon lewat AVAudioEngine dan menghasilkan
/// spektrum FFT dari buffer yang masuk.
final class MicrophoneCapture {
    private let engine = AVAudioEngine()
    private let analyzer = FFTAnalyzer(ukuranFFT: 1024)
    private var bufferTertampung: [Float] = []
    private let antrian = DispatchQueue(label: "com.pribadi.VisualizerTouchBar.mic")

    var onSpektrum: (([Float]) -> Void)?

    func mintaIzinMikrofon(selesai: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            selesai(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { diizinkan in
                DispatchQueue.main.async { selesai(diizinkan) }
            }
        default:
            selesai(false)
        }
    }

    func mulai() throws {
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.prosesBuffer(buffer)
        }

        engine.prepare()
        try engine.start()
    }

    func berhenti() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        antrian.async { [weak self] in
            self?.bufferTertampung.removeAll()
        }
    }

    private func prosesBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let jumlahFrame = Int(buffer.frameLength)
        let sampel = Array(UnsafeBufferPointer(start: data[0], count: jumlahFrame))

        antrian.async { [weak self] in
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
