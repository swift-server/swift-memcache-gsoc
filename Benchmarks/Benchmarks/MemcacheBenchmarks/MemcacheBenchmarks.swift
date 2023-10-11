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
import Foundation
import Memcache
import NIOCore
import NIOPosix

let benchmarks = {
    let defaultMetrics: [BenchmarkMetric] = [
        .mallocCountTotal,
        .mallocCountLarge,
        .mallocCountTotal,
        .memoryLeaked,
        .allocatedResidentMemory,
    ]

    Benchmark("Set Request", configuration: .init(metrics: defaultMetrics)) { benchmark in
        try await withThrowingTaskGroup(of: Void.self) { group in

            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: eventLoopGroup)

            group.addTask { try await memcacheConnection.run() }

            let setValue = "bar"
            try await memcacheConnection.set("foo", value: setValue)

            for _ in benchmark.scaledIterations {
                let getValue: String? = try await memcacheConnection.get("foo")
                assert(getValue == setValue, "Value retrieved from Memcache does not match the set value")
            }

            group.cancelAll()
        }
    }

    Benchmark("Set with TTL Request", configuration: .init(metrics: defaultMetrics)) { benchmark in
        try await withThrowingTaskGroup(of: Void.self) { group in

            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: eventLoopGroup)

            group.addTask { try await memcacheConnection.run() }

            let setValue = "foo"
            let now = ContinuousClock.Instant.now
            let expirationTime = now.advanced(by: .seconds(90))
            let timeToLive = TimeToLive.expiresAt(expirationTime)
            try await memcacheConnection.set("bar", value: setValue, timeToLive: timeToLive)

            for _ in benchmark.scaledIterations {
                let getValue: String? = try await memcacheConnection.get("foo")
                assert(getValue == setValue, "Value retrieved from Memcache does not match the set value")
            }

            group.cancelAll()
        }
    }

    Benchmark("Delete Request", configuration: .init(metrics: defaultMetrics)) { benchmark in
        try await withThrowingTaskGroup(of: Void.self) { group in
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: eventLoopGroup)

            group.addTask { try await memcacheConnection.run() }
            let setValue = "foo"
            try await memcacheConnection.set("bar", value: setValue)

            for _ in benchmark.scaledIterations {
                try await memcacheConnection.delete("bar")
            }

            group.cancelAll()
        }
    }

    Benchmark("Increment Request", configuration: .init(metrics: defaultMetrics)) { benchmark in
        try await withThrowingTaskGroup(of: Void.self) { group in
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: eventLoopGroup)

            group.addTask { try await memcacheConnection.run() }
            let initialValue = 1
            try await memcacheConnection.set("increment", value: initialValue)

            for _ in benchmark.scaledIterations {
                let incrementAmount = 100
                try await memcacheConnection.increment("increment", amount: incrementAmount)

                let newValue: Int? = try await memcacheConnection.get("increment")
                assert(newValue == initialValue + incrementAmount, "Incremented value is incorrect")
            }
            group.cancelAll()
        }
    }

    Benchmark("Decrement Request", configuration: .init(metrics: defaultMetrics)) { benchmark in
        try await withThrowingTaskGroup(of: Void.self) { group in
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: eventLoopGroup)

            group.addTask { try await memcacheConnection.run() }
            let initialValue = 100
            try await memcacheConnection.set("decrement", value: initialValue)

            for _ in benchmark.scaledIterations {
                let decrementAmount = 10
                try await memcacheConnection.decrement("decrement", amount: decrementAmount)

                let newValue: Int? = try await memcacheConnection.get("decrement")
                assert(newValue == initialValue - decrementAmount, "decrement value is incorrect")
            }
            group.cancelAll()
        }
    }
}
