import AppKit

/// Delegate utama aplikasi: menyalakan menu bar, Touch Bar controller, dan
/// menyinkronkan status run-at-login saat aplikasi selesai dijalankan.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        StatusBarController.shared.mulai()
        TouchBarController.shared.mulai()

        // Sinkronkan status run-at-login sebenarnya dari sistem (misal user
        // menghapusnya lewat System Settings langsung) ke SettingsStore.
        let statusSebenarnya = LoginItemManager.shared.statusAktifSaatIni()
        if statusSebenarnya != SettingsStore.shared.jalankanSaatLogin {
            SettingsStore.shared.jalankanSaatLogin = statusSebenarnya
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
