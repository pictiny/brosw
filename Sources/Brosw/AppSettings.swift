import Foundation

/// UserDefaults に保存するアプリ設定。変更時は changedNotification を post する。
enum AppSettings {
    static let changedNotification = Notification.Name("io.github.pictiny.Brosw.settingsChanged")

    enum ProfileSortOrder: String {
        /// 最近使ったプロファイルが上(既定)
        case recentFirst
        /// customProfileOrder の順
        case custom
    }

    private static let hiddenProfilesKey = "hiddenProfileDirectories"
    private static let hideMenuBarIconKey = "hideMenuBarIcon"
    private static let hideProfileEmailsKey = "hideProfileEmails"
    private static let sortOrderKey = "profileSortOrder"
    private static let customOrderKey = "customProfileOrder"

    /// ピッカーに表示しないプロファイルの id(`chrome:Profile 1` …)。
    static var hiddenProfileIDs: Set<String> {
        get { Set((UserDefaults.standard.stringArray(forKey: hiddenProfilesKey) ?? []).map(normalizeKey)) }
        set {
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: hiddenProfilesKey)
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    static var hideMenuBarIcon: Bool {
        get { UserDefaults.standard.bool(forKey: hideMenuBarIconKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: hideMenuBarIconKey)
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    /// ピッカーの各行にアカウントのメールアドレスを表示しない
    static var hideProfileEmails: Bool {
        get { UserDefaults.standard.bool(forKey: hideProfileEmailsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: hideProfileEmailsKey)
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    static var profileSortOrder: ProfileSortOrder {
        get {
            UserDefaults.standard.string(forKey: sortOrderKey)
                .flatMap(ProfileSortOrder.init(rawValue:)) ?? .recentFirst
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sortOrderKey)
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    /// カスタム並び順(プロファイル id の配列)
    static var customProfileOrder: [String] {
        get { (UserDefaults.standard.stringArray(forKey: customOrderKey) ?? []).map(normalizeKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: customOrderKey)
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    /// v0.2 までの Chrome 専用設定はディレクトリ名(`Profile 1`)を素で保存していた。
    /// ブラウザ非修飾のキーは Chrome のものとして id 形式(`chrome:Profile 1`)へ読み替える。
    private static func normalizeKey(_ key: String) -> String {
        key.contains(":") ? key : "\(Browser.chrome.rawValue):\(key)"
    }

    /// 設定に従って表示順を並べ替える。カスタム順に未登録のプロファイル
    /// (設定後に増えたものなど)は、元の順(最近使った順)のまま末尾に付ける。
    static func displayOrder(_ profiles: [BrowserProfile]) -> [BrowserProfile] {
        let order = customProfileOrder
        guard profileSortOrder == .custom, !order.isEmpty else {
            return profiles
        }
        let rank = Dictionary(
            uniqueKeysWithValues: order.enumerated().map { ($1, $0) }
        )
        return profiles.enumerated()
            .sorted { a, b in
                let rankA = rank[a.element.id] ?? Int.max
                let rankB = rank[b.element.id] ?? Int.max
                if rankA != rankB { return rankA < rankB }
                return a.offset < b.offset
            }
            .map(\.element)
    }
}
