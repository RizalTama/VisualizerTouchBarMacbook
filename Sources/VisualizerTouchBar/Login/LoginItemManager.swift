import Foundation
import ServiceManagement
import os.log

/// Mengelola status "Jalankan saat login" lewat SMAppService (API modern,
/// menggantikan SMLoginItemSetEnabled yang sudah deprecated).
///
/// Catatan: ini hanya berfungsi kalau aplikasi berjalan sebagai bundel .app
/// yang tersalin ke /Applications (lihat bagian "Build & install" di
/// CLAUDE.md), bukan saat dijalankan langsung lewat `swift run`.
final class LoginItemManager {
    static let shared = LoginItemManager()

    private let log = Logger(subsystem: "com.pribadi.VisualizerTouchBar", category: "LoginItem")

    private init() {}

    func terapkan(aktif: Bool) {
        do {
            if aktif {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            log.error("Gagal mengubah status jalankan-saat-login: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Status sebenarnya dari sistem, dipakai untuk sinkronisasi saat startup
    /// (misal user menghapus item login lewat System Settings langsung).
    func statusAktifSaatIni() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}
