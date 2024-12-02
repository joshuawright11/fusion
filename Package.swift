// swift-tools-version:6.0
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "fusion",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(name: "Fusion", targets: ["Fusion"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.1"),
    ],
    targets: [
        .macro(
            name: "Plugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Plugin"
        ),
        .target(name: "Fusion", dependencies: ["Plugin"], path: "Fusion"),
        .testTarget(name: "Tests", dependencies: ["Fusion"], path: "Tests"),
    ],
    swiftLanguageModes: [.v5]
)
