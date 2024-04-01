// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "XMLRPCServer",
    products: [
        .library(name: "XMLRPCServer", targets: ["XMLRPCServer"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/ilg/XMLRPCCoder.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/ilg/XMLRPCClient.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/envoy/Ambassador.git",
            from: "4.0.0"
        ),
        .package(
            url: "https://github.com/nicklockwood/SwiftFormat",
            from: "0.53.5"
        ),
    ],
    targets: [
        .target(
            name: "XMLRPCServer",
            dependencies: [
                .byName(name: "Ambassador"),
                .byName(name: "XMLRPCCoder"),
            ]
        ),
        .testTarget(
            name: "XMLRPCServerTests",
            dependencies: [
                .target(name: "XMLRPCServer"),
                .byName(name: "XMLRPCClient"),
                .product(name: "XMLAssertions", package: "XMLRPCCoder"),
                .product(name: "ResultAssertions", package: "XMLRPCClient"),
            ]
        ),
    ]
)
