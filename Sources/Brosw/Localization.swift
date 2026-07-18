import Foundation

/// メインバンドル(.app の Contents/Resources/*.lproj)から訳文を引く。
/// キーは英語原文。バンドル外で実行された場合は英語のまま表示される。
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
