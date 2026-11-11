// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ISearch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "i search", targets: ["ISearch"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ISearch",
            path: "Sources/ISearch",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Vision"),
                .linkedFramework("Security"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("WebKit")
            ]
        )
    ]
)
