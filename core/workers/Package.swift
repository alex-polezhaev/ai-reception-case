// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Workers",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "Shared", targets: ["Shared"]),
        .executable(name: "TranscriptionWorker", targets: ["TranscriptionWorker"]),
        .executable(name: "APIServer", targets: ["APIServer"]),
        .executable(name: "AnalysisWorker", targets: ["AnalysisWorker"]),
        .executable(name: "SessionWorker", targets: ["SessionWorker"]),
        .executable(name: "MiniApp", targets: ["MiniApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.29.3"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.8.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.26.1"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "APIServer",
            dependencies: [
                "Shared",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "JWT", package: "jwt"),
            ]
        ),
        .executableTarget(
            name: "AnalysisWorker",
            dependencies: [
                "Shared",
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
        .executableTarget(
            name: "SessionWorker",
            dependencies: [
                "Shared",
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
        .executableTarget(
            name: "TranscriptionWorker",
            dependencies: [
                "Shared",
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
        .executableTarget(
            name: "MiniApp",
            dependencies: [
                "Shared",
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Leaf", package: "leaf"),
            ]
        ),
        .target(
            name: "Shared",
            dependencies: [
                .product(name: "SotoS3", package: "soto"),
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]

        )
    ]
)
