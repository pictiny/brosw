import AppKit

enum ChromeLauncher {
    static var isChromeInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") != nil
    }

    /// `open -na "Google Chrome" --args --profile-directory=<dir> <urls...>` を実行する。
    /// URL は --args より後ろに置く(前に置くとデフォルトブラウザ=Brosw 自身に戻ってループする)。
    static func open(urls: [URL], profileDirectory: String?, onFailure: @escaping () -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        var arguments = ["-na", "Google Chrome", "--args"]
        if let profileDirectory {
            arguments.append("--profile-directory=\(profileDirectory)")
        }
        arguments.append(contentsOf: urls.map(\.absoluteString))
        process.arguments = arguments
        process.terminationHandler = { finished in
            if finished.terminationStatus != 0 {
                DispatchQueue.main.async(execute: onFailure)
            }
        }
        do {
            try process.run()
        } catch {
            onFailure()
        }
    }
}
