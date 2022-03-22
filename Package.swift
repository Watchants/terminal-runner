// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "terminal-runner",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        .executable(
            name: "Examples",
            targets: ["Examples"]),
        .library(
            name: "TerminalRunner",
            targets: ["TerminalRunner"]),
    ],
    dependencies: [
        
    ],
    targets: [
        .target(
            name: "TerminalRunner",
            dependencies: []),
        .executableTarget(
            name: "Examples",
            dependencies: ["TerminalRunner"]),
        .testTarget(
            name: "TerminalRunnerTests",
            dependencies: ["TerminalRunner"],
            path: "Tests"),
    ]
)
