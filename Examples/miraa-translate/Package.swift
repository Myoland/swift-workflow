// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "example",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/AFutureD/swift-gpt", branch: "ark-context-cache"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.4"),
        .package(url: "https://github.com/swift-server/swift-openapi-async-http-client", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "app",
            dependencies: [
                .product(name: "LLMFlow", package: "swift-workflow"),
                .product(name: "GPT", package: "swift-gpt"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
            ]
        ),
    ]
)
