// Resources/AppIcon.png (1024x1024 全面アートワーク) を
// macOS 標準のスクワークル(1024 キャンバスに 824 の角丸、余白 100)に
// マスクして Resources/AppIcon.icns を生成する。
// 使い方: make icon (リポジトリルートで実行すること)

import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let masterURL = root.appendingPathComponent("Resources/AppIcon.png")
let icnsURL = root.appendingPathComponent("Resources/AppIcon.icns")
let iconsetURL = root.appendingPathComponent(".build/AppIcon.iconset")

guard let master = NSImage(contentsOf: masterURL) else {
    fputs("error: \(masterURL.path) が読めません\n", stderr)
    exit(1)
}

/// 指定ピクセルサイズでスクワークルにマスクした 1 枚を描画する。
/// サイズごとに描き直すことで縮小時もエッジを保つ。
func renderMasked(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    let canvas = CGFloat(pixels)
    let content = canvas * 824 / 1024   // Apple のテンプレート比率
    let inset = (canvas - content) / 2
    let radius = content * 185.4 / 824  // Big Sur スクワークルの近似角丸

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let rect = NSRect(x: inset, y: inset, width: content, height: content)
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    master.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let fm = FileManager.default
try? fm.removeItem(at: iconsetURL)
try fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for point in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(point)x\(point).png" : "icon_\(point)x\(point)@2x.png"
        let rep = renderMasked(pixels: point * scale)
        try rep.representation(using: .png, properties: [:])!
            .write(to: iconsetURL.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fputs("error: iconutil failed\n", stderr)
    exit(1)
}
print("generated \(icnsURL.path)")
