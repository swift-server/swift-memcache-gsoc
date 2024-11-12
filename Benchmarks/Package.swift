// swift-tools-version: 5.9
//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftCertificates open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftCertificates project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftCertificates project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(name: "swift-memcache-gsoc", path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.11.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.56.0"),
    ],
    targets: [
        .executableTarget(
            name: "MemcacheBenchmarks",
            dependencies: [
                .product(name: "Memcache", package: "swift-memcache-gsoc"),
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ],
            path: "Benchmarks/MemcacheBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ]
)
