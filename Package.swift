// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenRecorder",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "ScreenRecorder",
            dependencies: [],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("SwiftUI"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Info.plist"
                ])
            ]
        ),
    ]
)
