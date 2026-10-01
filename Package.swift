// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WhisperDict",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "WhisperDict", targets: ["WhisperDict"])],
    targets: [
        .executableTarget(name: "WhisperDict", path: "Sources/WhisperDict", linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("AVFoundation"), .linkedFramework("Carbon"), .linkedFramework("ApplicationServices")]),
        .testTarget(name: "WhisperDictTests", dependencies: ["WhisperDict"], path: "Tests/WhisperDictTests")
    ]
)
