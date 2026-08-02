import AppKit

struct BrowserProfile: Identifiable {
    let browser: Browser
    /// プロファイルディレクトリ名(`Default`, `Profile 1`, …)。
    /// Local State が読めない新規インストール等では nil(プロファイル未指定で起動)。
    let directory: String?
    let name: String
    let email: String?
    let avatar: NSImage?
    /// アバター画像がない場合のプレースホルダー用(Chrome のプロファイルカラー)
    let fillColor: NSColor?
    let strokeColor: NSColor?
    let lastActiveTime: Double

    /// ブラウザ横断で一意な識別子(設定の hide/並び順キー)。例: `chrome:Profile 1`
    var id: String { "\(browser.rawValue):\(directory ?? "")" }
    var initial: String { String(name.prefix(1)).uppercased() }
}

enum BrowserProfileStore {
    private static var caches: [Browser: (mtime: Date, profiles: [BrowserProfile])] = [:]

    /// インストール済みの全対応ブラウザからプロファイル一覧を返す(各ブラウザ内は最近使った順)。
    static func loadProfiles() -> [BrowserProfile] {
        Browser.allCases.filter(\.isInstalled).flatMap(loadProfiles(for:))
    }

    /// 指定ブラウザの Local State からプロファイル一覧を返す。
    /// 読めない場合でもインストール済みなら、プロファイル未指定の 1 件を返す(新規インストール対策)。
    private static func loadProfiles(for browser: Browser) -> [BrowserProfile] {
        let dataDirectory = browser.dataDirectory
        let localStateURL = dataDirectory.appendingPathComponent("Local State")

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: localStateURL.path),
              let mtime = attrs[.modificationDate] as? Date
        else { return [fallbackProfile(for: browser)] }

        if let cache = caches[browser], cache.mtime == mtime {
            return cache.profiles
        }

        guard let data = try? Data(contentsOf: localStateURL),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let profileSection = json["profile"] as? [String: Any],
              let infoCache = profileSection["info_cache"] as? [String: [String: Any]],
              !infoCache.isEmpty
        else { return [fallbackProfile(for: browser)] }

        var profiles = infoCache.map { directory, info -> BrowserProfile in
            let name = (info["name"] as? String)
                ?? (info["gaia_name"] as? String)
                ?? directory
            let email = (info["user_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return BrowserProfile(
                browser: browser,
                directory: directory,
                name: name,
                email: email,
                avatar: loadAvatar(dataDirectory: dataDirectory, directory: directory, info: info),
                fillColor: skColor(info["default_avatar_fill_color"]),
                strokeColor: skColor(info["default_avatar_stroke_color"]),
                lastActiveTime: (info["active_time"] as? Double) ?? 0
            )
        }

        profiles.sort {
            if $0.lastActiveTime != $1.lastActiveTime {
                return $0.lastActiveTime > $1.lastActiveTime
            }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }

        caches[browser] = (mtime, profiles)
        return profiles
    }

    /// Local State が読めないインストール済みブラウザ用のプレースホルダー(プロファイル未指定)。
    private static func fallbackProfile(for browser: Browser) -> BrowserProfile {
        BrowserProfile(
            browser: browser,
            directory: nil,
            name: browser.displayName,
            email: nil,
            avatar: nil,
            fillColor: nil,
            strokeColor: nil,
            lastActiveTime: 0
        )
    }

    // MARK: - Avatar

    /// Chrome/Chromium 本体(ProfileAttributesEntry::GetAvatarIcon / IsUsingGAIAPicture)と
    /// 同じ優先順位でアバター画像を解決する:
    /// 「Google アカウントのアイコンを使う」(use_gaia_picture、またはアバター未カスタマイズ)
    /// なら gaia 画像 → プリセットアバター → gaia 画像 → nil(プレースホルダー描画)。
    /// use_gaia_picture はプリセット選択後にアカウントアイコンへ戻した場合にも立つため、
    /// is_using_default_avatar だけで判定するとプリセットを誤表示する。
    private static func loadAvatar(dataDirectory: URL, directory: String, info: [String: Any]) -> NSImage? {
        let gaiaFileName = (info["gaia_picture_file_name"] as? String)
            .flatMap { $0.isEmpty ? nil : $0 } ?? "Google Profile Picture.png"
        let gaiaURL = dataDirectory
            .appendingPathComponent(directory)
            .appendingPathComponent(gaiaFileName)

        let usesGaiaPicture = (info["use_gaia_picture"] as? Bool) ?? false
        let isUsingDefaultAvatar = (info["is_using_default_avatar"] as? Bool) ?? true
        if usesGaiaPicture || isUsingDefaultAvatar,
           let gaia = NSImage(contentsOf: gaiaURL) {
            return gaia
        }

        if let iconURL = info["avatar_icon"] as? String,
           let index = iconURL.split(separator: "_").last.flatMap({ Int($0) }),
           let fileName = modernAvatarFileNames[index] {
            let url = dataDirectory
                .appendingPathComponent("Avatars")
                .appendingPathComponent(fileName)
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        // プリセットが解決できない(レガシー番号やキャッシュ未取得)場合の最終フォールバック
        return NSImage(contentsOf: gaiaURL)
    }

    /// SkColor(ARGB の符号付き 32bit 整数)→ NSColor
    private static func skColor(_ value: Any?) -> NSColor? {
        guard let number = value as? NSNumber else { return nil }
        let argb = UInt32(bitPattern: number.int32Value)
        return NSColor(
            srgbRed: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255
        )
    }

    /// avatar_icon のインデックス → Avatars/ にキャッシュされるファイル名。
    /// Chromium chrome/browser/profiles/profile_avatar_icon_util.cc より。
    /// 0-25 のレガシーアバターは .pak 内蔵でファイルが存在しないため対象外
    /// (プレースホルダーにフォールバックする)。26 はプレースホルダー。
    private static let modernAvatarFileNames: [Int: String] = [
        27: "avatar_origami_cat.png",
        28: "avatar_origami_corgi.png",
        29: "avatar_origami_dragon.png",
        30: "avatar_origami_elephant.png",
        31: "avatar_origami_fox.png",
        32: "avatar_origami_monkey.png",
        33: "avatar_origami_panda.png",
        34: "avatar_origami_penguin.png",
        35: "avatar_origami_pinkbutterfly.png",
        36: "avatar_origami_rabbit.png",
        37: "avatar_origami_unicorn.png",
        38: "avatar_illustration_basketball.png",
        39: "avatar_illustration_bike.png",
        40: "avatar_illustration_bird.png",
        41: "avatar_illustration_cheese.png",
        42: "avatar_illustration_football.png",
        43: "avatar_illustration_ramen.png",
        44: "avatar_illustration_sunglasses.png",
        45: "avatar_illustration_sushi.png",
        46: "avatar_illustration_tamagotchi.png",
        47: "avatar_illustration_vinyl.png",
        48: "avatar_abstract_avocado.png",
        49: "avatar_abstract_cappuccino.png",
        50: "avatar_abstract_icecream.png",
        51: "avatar_abstract_icewater.png",
        52: "avatar_abstract_melon.png",
        53: "avatar_abstract_onigiri.png",
        54: "avatar_abstract_pizza.png",
        55: "avatar_abstract_sandwich.png",
    ]
}
