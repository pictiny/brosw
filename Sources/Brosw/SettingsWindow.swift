import AppKit
import SwiftUI

/// 設定ウィンドウ。閉じても解放せず、次回はそのまま前面に出す。
final class SettingsWindowController {
    private var window: NSWindow?
    private let model = SettingsViewModel()

    func show() {
        model.reload()

        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: model))
            let window = NSWindow(contentViewController: hosting)
            window.title = L("Brosw Settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        // LSUIElement アプリなので明示的に前面化しないとウィンドウが背後に出る
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
