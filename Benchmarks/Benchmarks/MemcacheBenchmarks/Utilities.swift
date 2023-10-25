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

func runSetRequest(iterations: Int, eventLoopGroup: EventLoopGroup) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: eventLoopGroup)
        group.addTask { try await memcacheConnection.run() }

        let setValue = "bar"

        for _ in 0..<iterations {
            try await memcacheConnection.set("foo", value: setValue)
        }
        group.cancelAll()
    }
}

func runSetWithTTLRequest(iterations: Int, eventLoopGroup: EventLoopGroup) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in

        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: eventLoopGroup)
        group.addTask { try await memcacheConnection.run() }

        let setValue = "foo"
        let now = ContinuousClock.Instant.now
        let expirationTime = now.advanced(by: .seconds(90))
        let timeToLive = TimeToLive.expiresAt(expirationTime)

        for _ in 0..<iterations {
            try await memcacheConnection.set("bar", value: setValue, timeToLive: timeToLive)
        }
        group.cancelAll()
    }
}

func runDeleteRequest(iterations: Int, eventLoopGroup: EventLoopGroup) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in

        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: eventLoopGroup)
        group.addTask { try await memcacheConnection.run() }

        let setValue = "foo"
        try await memcacheConnection.set("bar", value: setValue)

        for _ in 0..<iterations {
            try await memcacheConnection.delete("bar")
        }
        group.cancelAll()
    }
}

func runIncrementRequest(iterations: Int, eventLoopGroup: EventLoopGroup) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in

        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: eventLoopGroup)
        group.addTask { try await memcacheConnection.run() }

        let initialValue = 1
        try await memcacheConnection.set("increment", value: initialValue)

        let incrementAmount = 100
        for _ in 0..<iterations {
            try await memcacheConnection.increment("increment", amount: incrementAmount)
        }
        group.cancelAll()
    }
}

func runDecrementRequest(iterations: Int, eventLoopGroup: EventLoopGroup) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in

        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: eventLoopGroup)
        group.addTask { try await memcacheConnection.run() }

        let initialValue = 100
        try await memcacheConnection.set("decrement", value: initialValue)

        let decrementAmount = 10
        for _ in 0..<iterations {
            try await memcacheConnection.decrement("decrement", amount: decrementAmount)
        }
        group.cancelAll()
    }
}
