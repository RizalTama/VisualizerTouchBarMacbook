import AppKit
import SwiftUI

/// Jendela Pengaturan utama, sesuai mockup "Jendela Pengaturan@1x.png".
struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            headerView
            pratinjauView
            temaWarnaView
            sliderView
            teksStandbyView
            sumberAudioView
        }
        .padding(24)
        .frame(width: 720)
    }

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Visualizer Touch Bar")
                    .font(.system(size: 22, weight: .bold))
                Text("Ubah suara jadi batang warna di Touch Bar.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Text("Visualizer aktif")
                    .font(.subheadline)
                Toggle("", isOn: $settings.visualizerAktif)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.25)))
        }
    }

    private var pratinjauView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pratinjau Touch Bar")
                .font(.subheadline)
                .foregroundColor(.secondary)
            PratinjauVisualizerView(
                warnaAwal: settings.warnaGradientAktif.awal,
                warnaAkhir: settings.warnaGradientAktif.akhir
            )
            .frame(height: 60)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black))
        }
    }

    private var temaWarnaView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tema warna")
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                ForEach(TemaWarna.allCases) { tema in
                    kartuTema(tema)
                }
            }
        }
    }

    private func kartuTema(_ tema: TemaWarna) -> some View {
        let terpilih = settings.tema == tema
        let gradient: LinearGradient
        if let bawaan = tema.warnaGradientBawaan {
            gradient = LinearGradient(
                colors: [Color(nsColor: bawaan.awal), Color(nsColor: bawaan.akhir)],
                startPoint: .leading, endPoint: .trailing
            )
        } else {
            gradient = LinearGradient(
                colors: [Color(nsColor: settings.warnaBebas)],
                startPoint: .leading, endPoint: .trailing
            )
        }

        return VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(gradient)
                .frame(height: 18)
            Text(tema.namaTampilan)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.25)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(terpilih ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            settings.tema = tema
            if tema == .bebas {
                bukaColorPanel()
            }
        }
    }

    private func bukaColorPanel() {
        let panel = NSColorPanel.shared
        panel.color = settings.warnaBebas
        panel.showsAlpha = false
        NSColorPanelObserver.shared.mulaiAmati { warnaBaru in
            settings.warnaBebas = warnaBaru
        }
        panel.makeKeyAndOrderFront(nil)
    }

    private var sliderView: some View {
        HStack(alignment: .top, spacing: 24) {
            sliderItem(judul: "Sensitivitas", nilaiTampilan: "\(Int(settings.sensitivitas * 100))%") {
                Slider(value: $settings.sensitivitas, in: 0...1)
            }
            sliderItem(judul: "Jumlah batang", nilaiTampilan: "\(settings.jumlahBatang)") {
                Slider(
                    value: Binding(
                        get: { Double(settings.jumlahBatang) },
                        set: { settings.jumlahBatang = Int($0) }
                    ),
                    in: 8...100,
                    step: 1
                )
            }
            sliderItem(judul: "Kecepatan animasi", nilaiTampilan: "\(Int(settings.kecepatanAnimasi * 100))%") {
                Slider(value: $settings.kecepatanAnimasi, in: 0.05...1)
            }
            sliderItem(judul: "Dorongan nada tinggi", nilaiTampilan: tampilanDoronganTrebel) {
                Slider(value: $settings.doronganTrebel, in: -0.5...0.5)
            }
        }
    }

    private var tampilanDoronganTrebel: String {
        let persen = Int((settings.doronganTrebel * 100).rounded())
        return persen > 0 ? "+\(persen)%" : "\(persen)%"
    }

    private func sliderItem<S: View>(
        judul: String, nilaiTampilan: String, @ViewBuilder slider: () -> S
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(judul).font(.subheadline)
                Spacer()
                Text(nilaiTampilan).font(.subheadline).foregroundColor(.secondary)
            }
            slider()
        }
        .frame(maxWidth: .infinity)
    }

    private var teksStandbyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Teks saat idle (opsional)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("Contoh: Rizal ♥️ Tika", text: $settings.teksStandby)
                .textFieldStyle(.roundedBorder)
            Text("Kalau diisi, Touch Bar ganti ke teks ini kalau tidak ada suara selama 3 detik. Kosongkan untuk matikan mode ini.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var sumberAudioView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sumber audio")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(spacing: 0) {
                    tombolSumber(.mikrofon)
                    tombolSumber(.audioSistem)
                }
                .background(Capsule().fill(Color.black.opacity(0.25)))
            }
            Spacer()
            Toggle("Jalankan saat login", isOn: $settings.jalankanSaatLogin)
                .toggleStyle(.checkbox)
        }
    }

    private func tombolSumber(_ sumber: SumberAudio) -> some View {
        let terpilih = settings.sumberAudio == sumber
        return Text(sumber.namaTampilan)
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(terpilih ? Capsule().fill(Color.accentColor) : Capsule().fill(Color.clear))
            .foregroundColor(terpilih ? .white : .primary)
            .contentShape(Capsule())
            .onTapGesture {
                settings.sumberAudio = sumber
            }
    }
}
