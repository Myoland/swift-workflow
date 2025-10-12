// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "example",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swift-otel/swift-otel", from: "1.0.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.4"),
        .package(url: "https://github.com/swift-server/swift-openapi-async-http-client", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-configuration", from: "0.1.1", traits: [.defaults]),
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "app",
            dependencies: [
                .product(name: "LLMFlow", package: "swift-workflow"),
                .product(name: "OTel", package: "swift-otel"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Instrumentation", package: "swift-distributed-tracing"),
            ]
        ),
    ]
)
