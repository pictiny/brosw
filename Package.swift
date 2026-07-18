// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Brosw",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Brosw",
            path: "Sources/Brosw",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
