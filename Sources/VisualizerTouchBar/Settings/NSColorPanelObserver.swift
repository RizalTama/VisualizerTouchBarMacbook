import AppKit

/// Jembatan target-action untuk NSColorPanel (API AppKit lama yang memakai
/// Objective-C selector), supaya perubahan warna bisa diteruskan lewat closure.
final class NSColorPanelObserver: NSObject {
    static let shared = NSColorPanelObserver()

    private var onChange: ((NSColor) -> Void)?

    private override init() {}

    func mulaiAmati(onChange: @escaping (NSColor) -> Void) {
        self.onChange = onChange
        NSColorPanel.shared.setTarget(self)
        NSColorPanel.shared.setAction(#selector(warnaBerubah(_:)))
    }

    @objc private func warnaBerubah(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}
