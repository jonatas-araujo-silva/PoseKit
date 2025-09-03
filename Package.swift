// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PoseKit", 
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "PoseKit",
            targets: ["PoseKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PoseKit",
            dependencies: []),
    ]
)
