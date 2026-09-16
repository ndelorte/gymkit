// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AppGymKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "AppGymKit", targets: ["AppGymKit"])
    ],
    targets: [
        .target(name: "AppGymKit"),
        .testTarget(name: "AppGymKitTests", dependencies: ["AppGymKit"])
    ]
)
