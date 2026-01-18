// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftFanfou",
    platforms: [.iOS(.v13), .macOS(.v12), .tvOS(.v13), .watchOS(.v7)],
    products: [.library(name: "SwiftFanfou", targets: ["SwiftFanfou"])],
    targets: [
        .target(name: "SwiftFanfou")
    ]
)