import AppKit
import SwiftUI

/// borderless でもキーウィンドウになれる、アプリを前面化しないパネル。
final class PickerPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?
    var onCancel: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) != true {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

final class PickerController: NSObject, NSWindowDelegate {
    var onOpenSettings: (() -> Void)?

    private var panel: PickerPanel?
    private let model = PickerViewModel()

    override init() {
        super.init()
        model.onChoose = { [weak self] index in self?.choose(index) }
        model.onCancel = { [weak self] in self?.dismiss() }
        model.onOpenSettings = { [weak self] in
            self?.dismiss()
            self?.onOpenSettings?()
        }
    }

    // MARK: - Entry point

    func present(urls: [URL]) {
        // ピッカー表示中に届いた URL は同一セッションに束ねる
        if panel != nil {
            model.urls.append(contentsOf: urls)
            return
        }

        var profiles = AppSettings.displayOrder(BrowserProfileStore.loadProfiles())
        guard !profiles.isEmpty else {
            fail(urls: urls, message: L("No supported browser was found."))
            return
        }

        let hidden = AppSettings.hiddenProfileIDs
        let visible = profiles.filter { !hidden.contains($0.id) }
        if !visible.isEmpty {
            // 全件非表示にされてしまった場合は行き止まり防止のため全件表示に戻す
            profiles = visible
        }
        if profiles.count <= 1 {
            if let only = profiles.first { launch(profile: only, urls: urls) }
            return
        }

        model.urls = urls
        model.profiles = profiles
        model.selectedIndex = 0
        model.showEmails = !AppSettings.hideProfileEmails
        model.showBrowserBadge = !AppSettings.hideBrowserBadge
        showPanel()
    }

    /// 表示中のピッカーをキャンセル扱いで閉じる(設定ウィンドウを開くときなど)。
    func cancel() {
        dismiss()
    }

    // MARK: - Panel lifecycle

    private func showPanel() {
        let hosting = NSHostingView(rootView: PickerView(model: model))
        hosting.frame.size = hosting.fittingSize

        let panel = PickerPanel(contentRect: hosting.frame)
        panel.contentView = hosting
        panel.delegate = self
        panel.keyHandler = { [weak self] event in
            self?.handleKey(event) ?? false
        }
        panel.onCancel = { [weak self] in self?.dismiss() }
        position(panel)
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    /// マウスカーソルのあるスクリーン上、カーソル近傍に配置する(画面端で補正)。
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x + 8, y: mouse.y - size.height - 8)
        origin.x = min(max(visible.minX, origin.x), visible.maxX - size.width)
        origin.y = min(max(visible.minY, origin.y), visible.maxY - size.height)
        panel.setFrameOrigin(origin)
    }

    private func dismiss() {
        guard let panel else { return }
        self.panel = nil
        panel.delegate = nil
        panel.keyHandler = nil
        panel.onCancel = nil
        panel.close()
        model.urls = []
    }

    func windowDidResignKey(_ notification: Notification) {
        // パネル外クリックなどでフォーカスが外れたらキャンセル扱い
        dismiss()
    }

    // MARK: - Actions

    private func choose(_ index: Int) {
        guard model.profiles.indices.contains(index) else { return }
        let urls = model.urls
        let profile = model.profiles[index]
        dismiss()
        launch(profile: profile, urls: urls)
    }

    private func copyAndClose() {
        copyToPasteboard(urls: model.urls)
        dismiss()
    }

    private func launch(profile: BrowserProfile, urls: [URL]) {
        BrowserLauncher.open(profile: profile, urls: urls) { [weak self] in
            self?.fail(urls: urls, message: String(format: L("Could not launch %@."), profile.browser.appName))
        }
    }

    private func fail(urls: [URL], message: String) {
        copyToPasteboard(urls: urls)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = L("The URLs have been copied to the clipboard.") + "\n"
            + urls.map(\.absoluteString).joined(separator: "\n")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func copyToPasteboard(urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(urls.map(\.absoluteString).joined(separator: "\n"), forType: .string)
    }

    // MARK: - Keyboard

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // Esc
            dismiss()
            return true
        case 36, 76: // Return / Enter
            choose(model.selectedIndex)
            return true
        case 126: // Up
            model.selectedIndex = max(0, model.selectedIndex - 1)
            return true
        case 125: // Down
            model.selectedIndex = min(model.profiles.count - 1, model.selectedIndex + 1)
            return true
        default:
            break
        }

        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "c" {
            copyAndClose()
            return true
        }

        if let characters = event.charactersIgnoringModifiers,
           let number = Int(characters),
           (1...9).contains(number),
           number <= model.profiles.count {
            choose(number - 1)
            return true
        }

        return false
    }
}
