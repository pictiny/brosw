import AppKit

/// 対応ブラウザ。現状はすべて Chromium 系(Local State の profile.info_cache を持ち、
/// `--profile-directory` でプロファイルを指定して起動できる)。
enum Browser: String, CaseIterable {
    case chrome
    case brave
    case vivaldi

    var bundleID: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .brave: return "com.brave.Browser"
        case .vivaldi: return "com.vivaldi.Vivaldi"
        }
    }

    /// `open -na "<name>"` に渡すアプリ名
    var appName: String {
        switch self {
        case .chrome: return "Google Chrome"
        case .brave: return "Brave Browser"
        case .vivaldi: return "Vivaldi"
        }
    }

    /// ピッカー/設定に出す短い表示名
    var displayName: String {
        switch self {
        case .chrome: return "Chrome"
        case .brave: return "Brave"
        case .vivaldi: return "Vivaldi"
        }
    }

    /// プロファイルデータ(Local State / Avatars/ / 各プロファイルディレクトリ)のルート
    var dataDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .chrome:
            return home.appendingPathComponent("Library/Application Support/Google/Chrome")
        case .brave:
            return home.appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser")
        case .vivaldi:
            return home.appendingPathComponent("Library/Application Support/Vivaldi")
        }
    }

    var applicationURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    var isInstalled: Bool { applicationURL != nil }

    /// ピッカーのブラウザバッジ用アプリアイコン(未インストールなら nil)
    var appIcon: NSImage? {
        guard let url = applicationURL else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
