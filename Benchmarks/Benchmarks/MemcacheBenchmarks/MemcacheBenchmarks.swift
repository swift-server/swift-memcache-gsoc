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
import ServiceLifecycle

let benchmarks = {
    Benchmark("SomeBenchmark") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Date()) // replace this line with your own benchmark
        }
    }
    // Add additional benchmarks here

    Benchmark("Memcached Set Request", configuration: .init(metrics: [.mallocCountSmall, .mallocCountLarge, .mallocCountTotal, .memoryLeaked, .allocatedResidentMemory])) { benchmark in
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
}
