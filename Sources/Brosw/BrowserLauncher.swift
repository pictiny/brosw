import AppKit

enum BrowserLauncher {
    /// 選択されたプロファイルのブラウザで URL を開く。
    /// `open -na "<app>" --args --profile-directory=<dir> <urls...>` を実行する。
    /// URL は --args より後ろに置く(前に置くとデフォルトブラウザ=Brosw 自身に戻ってループする)。
    static func open(profile: BrowserProfile, urls: [URL], onFailure: @escaping () -> Void) {
        let browser = profile.browser
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        var arguments = ["-na", browser.appName, "--args"]
        if let directory = profile.directory {
            arguments.append("--profile-directory=\(directory)")
        }
        arguments.append(contentsOf: urls.map(\.absoluteString))
        process.arguments = arguments
        process.terminationHandler = { finished in
            if finished.terminationStatus != 0 {
                DispatchQueue.main.async(execute: onFailure)
                return
            }
            // open は -n で起動した使い捨てインスタンスを前面化しようとするが、
            // それは既存本体へ受け渡して即終了するため前面化が効かない。
            // 明示的に本体を前面化する。使い捨てと本体が一瞬並存しうるので、
            // 起動時刻が最も古い(= URL を実際に表示する本体)を選ぶ。
            DispatchQueue.main.async {
                NSRunningApplication
                    .runningApplications(withBundleIdentifier: browser.bundleID)
                    .filter { !$0.isTerminated }
                    .min { ($0.launchDate ?? .distantFuture) < ($1.launchDate ?? .distantFuture) }?
                    .activate(options: [.activateIgnoringOtherApps])
            }
        }
        do {
            try process.run()
        } catch {
            onFailure()
        }
    }
}
