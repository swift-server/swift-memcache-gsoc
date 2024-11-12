//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-memcache-gsoc open source project
//
// Copyright (c) 2023 Apple Inc. and the swift-memcache-gsoc project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of swift-memcache-gsoc project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
import Memcache
import NIOCore
import NIOPosix

private let eventLoopGroup = MultiThreadedEventLoopGroup.singleton.next()

let benchmarks = {
    let defaultMetrics: [BenchmarkMetric] = [
        .mallocCountTotal
    ]

    Benchmark(
        "Set Request",
        configuration: .init(
            metrics: defaultMetrics,
            timeUnits: .milliseconds
        )
    ) { benchmark in
        try await runSetRequest(iterations: benchmark.scaledIterations.upperBound, eventLoopGroup: eventLoopGroup)
    }

    Benchmark(
        "Set with TTL Request",
        configuration: .init(
            metrics: defaultMetrics,
            timeUnits: .milliseconds
        )
    ) { benchmark in
        try await runSetWithTTLRequest(
            iterations: benchmark.scaledIterations.upperBound,
            eventLoopGroup: eventLoopGroup
        )
    }
    Benchmark(
        "Delete Request",
        configuration: .init(
            metrics: defaultMetrics,
            timeUnits: .milliseconds
        )
    ) { benchmark in
        try await runDeleteRequest(iterations: benchmark.scaledIterations.upperBound, eventLoopGroup: eventLoopGroup)
    }

    Benchmark(
        "Increment Request",
        configuration: .init(
            metrics: defaultMetrics,
            timeUnits: .milliseconds
        )
    ) { benchmark in
        try await runIncrementRequest(iterations: benchmark.scaledIterations.upperBound, eventLoopGroup: eventLoopGroup)
    }

    Benchmark(
        "Decrement Request",
        configuration: .init(
            metrics: defaultMetrics,
            timeUnits: .milliseconds
        )
    ) { benchmark in
        try await runDecrementRequest(iterations: benchmark.scaledIterations.upperBound, eventLoopGroup: eventLoopGroup)
    }
}
