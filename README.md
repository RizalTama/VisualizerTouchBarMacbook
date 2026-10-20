# 🎚️ Visualizer Touch Bar

**Ubah suara jadi batang warna yang hidup — langsung di Touch Bar MacBook Pro kamu.**

Aplikasi macOS native untuk menampilkan visualizer audio real-time (gaya equalizer)
di Touch Bar, lengkap dengan menu bar control dan jendela Pengaturan yang bisa
dikustomisasi penuh: tema warna, sensitivitas, jumlah batang, sampai mode
"standby" yang nampilin teks custom pas lagi sepi suara.

Dibangun murni dengan **Swift Package Manager** — tanpa Xcode project, tanpa
storyboard — UI ditulis manual lewat SwiftUI (jendela Pengaturan) dan AppKit
(Touch Bar & menu bar).

![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6.2-orange)
![SPM](https://img.shields.io/badge/build-Swift%20Package%20Manager-blue)

---

## ✨ Fitur

- 🎛️ **Visualizer real-time di Touch Bar** — batang warna gradient yang
  bereaksi ke audio, ditampilkan langsung di Touch Bar fisik (menggantikan
  tampilan Touch Bar normal selagi aktif, mirip aplikasi seperti Pock).
- 🎨 **5 tema warna** (Neon, Sunset, Lautan, Monokrom) + color picker bebas.
- 🎙️ **Dua sumber audio**: Mikrofon, atau Audio Sistem (ikut musik yang lagi
  diputar) lewat ScreenCaptureKit.
- 🎚️ **Tuning lengkap**: sensitivitas, jumlah batang (8–100), kecepatan
  animasi, dan dorongan nada tinggi — biar visualisasinya hidup di semua
  frekuensi, bukan cuma bass yang kelihatan gerak.
- 💤 **Mode standby**: kalau gak ada suara 3 detik, Touch Bar otomatis ganti
  nampilin teks custom (emoji juga bisa!) alih-alih batang diam.
- 🖥️ **Kontrol dari menu bar**: toggle on/off, ganti tema, pilih sumber audio,
  jalankan saat login — semua tanpa buka jendela Pengaturan.
- 💾 Semua setting tersimpan otomatis (UserDefaults), auto-gain per-batang
  biar visualizer selalu kelihatan "hidup" di volume berapa pun.

## 📸 Tampilan

| Menu bar | Jendela Pengaturan | Touch Bar |
|---|---|---|
| <img src="Menu bar@1x.png" width="260"> | <img src="Jendela Pengaturan@1x.png" width="320"> | <img src="Tampilan di Touch Bar@1x.png" width="320"> |

## 🚀 Build & jalankan

Butuh Xcode Command Line Tools (bukan Xcode penuh) + Swift 6.

```bash
git clone https://github.com/RizalTama/VisualizerTouchBarMacbookPro.git
cd VisualizerTouchBarMacbookPro

# Build + bungkus jadi .app siap pakai
./Scripts/buat_sertifikat_dev.sh   # sekali saja, lihat penjelasan di bawah
./Scripts/build_app.sh

# Install
cp -R "Visualizer Touch Bar.app" /Applications/
```

Kalau macOS menolak buka pertama kali (Gatekeeper): klik kanan ikon app →
**Open**.

> Butuh akses Mikrofon (dan Screen Recording kalau pakai sumber Audio
> Sistem) — macOS akan minta izin otomatis saat fitur terkait dipakai.

## 🏗️ Arsitektur

```
Sources/VisualizerTouchBar/
├── App/        entry point & app delegate
├── Audio/      FFT (Accelerate/vDSP), capture mic & audio sistem,
│               koordinator engine
├── TouchBar/   presentasi Touch Bar modal + view batang visualizer
├── Settings/   SwiftUI Pengaturan + penyimpanan UserDefaults
├── MenuBar/    NSStatusItem & menu dropdown
└── Login/      kelola status "jalankan saat login"
```

**Alur audio:** mic/system audio → FFT (vDSP) → kompensasi spektrum +
auto-gain per-batang → smoothing attack/release → digambar di Touch Bar
(dan di pratinjau jendela Pengaturan, sumber data yang sama).

## 🔧 Tantangan teknis

Project ini banyak gali area yang nyaris gak terdokumentasi resmi oleh
Apple. Dua tantangan terbesarnya:

<details>
<summary><strong>1. Menampilkan visualizer di Touch Bar saat aplikasi lain aktif</strong> (API privat, lokasinya pindah antar versi macOS)</summary>

<br>

Touch Bar normal cuma nampilin kontrol dari app yang sedang aktif/depan.
Supaya visualizer tetap tampil walau sedang buka app lain, perlu API privat
Apple: `presentSystemModalTouchBar:placement:systemTrayItemIdentifier:`.

Di versi macOS lama, method ini ada sebagai **instance method di
`NSApplication`**. Tapi di macOS 26 (yang dipakai buat develop project ini),
Apple diam-diam **memindahkannya jadi class method di `NSTouchBar`** — tanpa
error apa pun kalau dipanggil di lokasi lama, cuma gagal diam-diam (optional
chaining return `nil`). Ketemu lewat scan langsung ke Objective-C runtime
(`class_copyMethodList`) buat cari di mana sebenarnya method itu sekarang
hidup, bukan nebak dari dokumentasi/forum yang sudah basi.

Dipanggil lewat `class_getClassMethod` + `method_getImplementation` (ambil
IMP method lalu panggil langsung sebagai fungsi C) — **bukan**
`unsafeBitCast(SomeClass.self, to: AnyObject.self)` + `perform(_:with:)`,
karena cara itu bikin **SEGFAULT diam-diam** (metatype Swift ternyata gak
aman di-bitcast jadi objek).

Detail lengkap + kode scan runtime-nya ada di komentar
`TouchBarController.swift`.

</details>

<details>
<summary><strong>2. Izin Screen Recording yang reset sendiri tiap rebuild</strong> (gotcha code signing)</summary>

<br>

Ad-hoc code signing (`codesign --sign -`, tanpa sertifikat) menghasilkan
**CDHash baru di setiap build**. Izin Screen Recording (dibutuhkan
`SystemAudioCapture` lewat ScreenCaptureKit) di macOS ternyata terikat ketat
ke CDHash itu — jadi tiap kali rebuild, izin yang sudah di-grant user balik
lagi ke "declined", walau toggle di System Settings kelihatan ON (nempel ke
versi binary yang lama).

Solusinya: bikin sertifikat code-signing **self-signed lokal** yang stabil
(`Scripts/buat_sertifikat_dev.sh`) dan sign pakai itu, bukan ad-hoc. Ini
tidak 100% menghilangkan masalah (CDHash tetap berubah tiap build apa pun
metode signing-nya), tapi memberi identitas yang konsisten — solusi penuh
butuh Apple Developer ID berbayar + notarization, yang gak worth it untuk
app pribadi yang gak didistribusikan.

</details>

## 📋 Referensi pengaturan

| Setting | Default | Range |
|---|---|---|
| Sensitivitas | 70% | 0–100% |
| Jumlah batang | 40 | 8–100 |
| Kecepatan animasi | 60% | 5–100% |
| Dorongan nada tinggi | 0% (netral) | -50% – +50% |
| Teks standby | kosong (nonaktif) | bebas, emoji boleh |
| Durasi sepi → standby | 3 detik | — |

## ⚠️ Status & keterbatasan

- Sumber **Mikrofon** sudah teruji stabil.
- Sumber **Audio Sistem** butuh izin Screen Recording yang kadang perlu
  di-grant ulang manual di System Settings setiap rebuild dari source (lihat
  bagian tantangan teknis di atas) — ini batasan dari macOS, bukan bug.
- Pakai API privat Apple untuk fitur Touch Bar modal → berpotensi
  rusak/berubah di update macOS berikutnya tanpa peringatan.

## 🛠️ Tech stack

Swift 6.2 · SwiftUI · AppKit (NSTouchBar, NSStatusItem) · AVFoundation ·
ScreenCaptureKit · Accelerate (vDSP/FFT) · Swift Package Manager

---

Dibuat & dikembangkan oleh **[RizalTama](https://github.com/RizalTama)** 🧡
