// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-workflow",
    platforms: [.macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LLMFlow",
            targets: ["LLMFlow"]
        ),
    ],
    dependencies: [
//        .package(path: "../swift-lazy"),
//        .package(path: "../swift-gpt"),
        .package(url: "https://github.com/AFutureD/swift-gpt", branch: "main"),
        .package(url: "https://github.com/Myoland/swift-lazy", branch: "main"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/objecthub/swift-dynamicjson", from: "1.0.2"),
        .package(url: "https://github.com/maiqingqiang/Jinja", branch: "main"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.3.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.8.2"),
        .package(url: "https://github.com/AFutureD/swift-synchronization", branch: "main"),
        
        // Test
        .package(url: "https://github.com/swift-server/swift-openapi-async-http-client", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LLMFlow",
            dependencies: [
                .product(name: "SynchronizationKit", package: "swift-synchronization"),
                .product(name: "LazyKit", package: "swift-lazy"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "DynamicJSON", package: "swift-dynamicjson"),
                .product(name: "Jinja", package: "Jinja"),
                .product(name: "GPT", package: "swift-gpt"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ]
        ),
        .testTarget(
            name: "LLMFlowTests",
            dependencies: [
                "LLMFlow",
                .product(name: "Yams", package: "Yams"),
                .product(name: "TestKit", package: "swift-lazy"),
                .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
            ],
            resources: [.process("Resources")]
        ),
    ]
)
