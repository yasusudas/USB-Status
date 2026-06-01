// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "USBStatus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "USBStatus", targets: ["USBStatus"])
    ],
    targets: [
        .executableTarget(
            name: "USBStatus",
            path: "Sources/USBStatus",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "USBStatusTests",
            dependencies: ["USBStatus"]
        )
    ]
)
