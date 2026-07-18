import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let picker = PickerController()
    private let settingsWindow = SettingsWindowController()
    private var hasReceivedURLs = false

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        picker.onOpenSettings = { [weak self] in self?.showSettings() }
        updateStatusItem()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: AppSettings.changedNotification,
            object: nil
        )

        // アイコン非表示中に(URL 経由でなく)手動起動されたら設定を開く。
        // URL 経由の自動起動と区別するため少し待つ。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.hasReceivedURLs, AppSettings.hideMenuBarIcon else { return }
            self.showSettings()
        }
    }

    private func showSettings() {
        // ピッカー表示中に設定を開いた場合、activate が非同期なので
        // resignKey に頼らず明示的に閉じる
        picker.cancel()
        settingsWindow.show()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        hasReceivedURLs = true
        // http/https に加え、Finder から渡されるローカル HTML(CFBundleDocumentTypes で
        // public.html を宣言しているため file URL でも届く)を受け付ける
        let openableURLs = urls.filter { url in
            let scheme = url.scheme?.lowercased() ?? ""
            return scheme == "http" || scheme == "https" || url.isFileURL
        }
        guard !openableURLs.isEmpty else { return }
        picker.present(urls: openableURLs)
    }

    /// 常駐中にもう一度起動(Finder / Spotlight / open -a Brosw)されたら設定を開く。
    /// メニューバーアイコン非表示時の設定への入口。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Status item

    @objc private func settingsChanged() {
        updateStatusItem()
    }

    /// バンドル同梱のテンプレート画像。無い場合(バンドル外実行など)は SF Symbol で代替。
    private static func statusIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "fish.fill", accessibilityDescription: "Brosw")
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true  // ライト/ダークメニューバーに合わせて自動反転
        image.accessibilityDescription = "Brosw"
        return image
    }

    private func updateStatusItem() {
        if AppSettings.hideMenuBarIcon {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.statusIcon()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !DefaultBrowser.isDefault {
            let setDefault = NSMenuItem(
                title: L("Set as Default Browser"),
                action: #selector(setAsDefaultBrowser),
                keyEquivalent: ""
            )
            setDefault.target = self
            menu.addItem(setDefault)
            menu.addItem(.separator())
        }

        #if DEBUG
        let test = NSMenuItem(
            title: L("Test: Show Picker"),
            action: #selector(showTestPicker),
            keyEquivalent: ""
        )
        test.target = self
        menu.addItem(test)
        #endif

        let settings = NSMenuItem(
            title: L("Settings…"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        var versionTitle = "Brosw v\(version)"
        #if DEBUG
        versionTitle += " (debug)"
        #endif
        let versionItem = NSMenuItem(title: versionTitle, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let quit = NSMenuItem(
            title: L("Quit Brosw"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)
    }

    @objc private func setAsDefaultBrowser() {
        DefaultBrowser.requestSetDefault()
    }

    @objc private func openSettings() {
        showSettings()
    }

    #if DEBUG
    @objc private func showTestPicker() {
        picker.present(urls: [URL(string: "https://example.com/")!])
    }
    #endif
}

enum DefaultBrowser {
    static var isDefault: Bool {
        guard let handler = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) else {
            return false
        }
        return Bundle(url: handler)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    static func requestSetDefault() {
        // macOS が確認ダイアログを表示する。http に設定すれば https も追随する。
        request(app: Bundle.main.bundleURL)
    }

    /// デフォルトブラウザの役割を Chrome に返す(Brosw をやめるとき用)。
    static func requestSetChromeDefault() {
        guard let chrome = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.google.Chrome"
        ) else { return }
        request(app: chrome)
    }

    private static func request(app: URL) {
        NSWorkspace.shared.setDefaultApplication(
            at: app,
            toOpenURLsWithScheme: "http"
        ) { error in
            if let error {
                NSLog("Failed to set default browser: \(error.localizedDescription)")
            }
        }
    }
}
