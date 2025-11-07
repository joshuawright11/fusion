// swift-tools-version:6.2
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "fusion",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(name: "Fusion", targets: ["Fusion"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
    ],
    targets: [
        .macro(
            name: "FusionPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "FusionPlugin/Sources"
        ),
        .target(name: "Fusion", dependencies: ["FusionPlugin"], path: "Fusion/Sources"),
        .testTarget(name: "FusionTests", dependencies: ["Fusion"], path: "Fusion/Tests"),
    ],
    swiftLanguageModes: [.v5, .v6]
)
