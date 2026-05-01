// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EncodeDecode",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS(.v13),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "EncodeDecode",
            targets: ["EncodeDecode"]
        ),
    ],
    targets: [
        .target(
            name: "EncodeDecode"
        ),
        
        .testTarget(
            name: "EncodeDecodeTests",
            dependencies: ["EncodeDecode"],
            resources: [.process("Resources")]
        ),        
    ]
)
