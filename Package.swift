// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SwiftGodotCLI",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "swiftgodotbuilder", targets: ["SwiftGodotCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", "1.3.0"..<"1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftGodotCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            // fix for multi-file Swift 6 executables using @main
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
    ]
)
