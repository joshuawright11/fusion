// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Fusion",
    products: [
        .library(name: "Fusion", targets: ["Fusion"]),
    ],
    targets: [
        .target(name: "Fusion", dependencies: []),
        .testTarget(name: "FusionTests", dependencies: ["Fusion"]),
    ]
)
