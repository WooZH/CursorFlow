// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CursorFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CursorFlow", targets: ["CursorFlow"])
    ],
    targets: [
        .executableTarget(
            name: "CursorFlow",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        )
    ]
)
