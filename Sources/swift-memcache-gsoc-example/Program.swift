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

import NIOCore
import NIOPosix
import SwiftMemcache

@available(macOS 13.0, *)
@main
struct Program {
    // Create an event loop group with a single thread
    static let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    static func main() async throws {
        // Instantiate a new MemcachedConnection actor with host, port, and event loop group
        let memcachedConnection = MemcachedConnection(host: "127.0.0.1", port: 11211, eventLoopGroup: eventLoopGroup)

        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add the connection actor's run function to the task group
            // This opens the connection and handles requests until the task is cancelled or the connection is closed
            group.addTask { try await memcachedConnection.run() }

            // Set a value for a key.
            let setValue = "bar"
            let now = ContinuousClock.Instant.now
            let expiration = now.advanced(by: .seconds(90))
            try await memcachedConnection.set("foo", value: setValue, expiration: expiration)

            // Get the value for a key.
            // Specify the expected type for the value returned from Memcache.
            let getValue: String? = try await memcachedConnection.get("foo")

            // Assert that the get operation was successful by comparing the value set and the value returned from Memcache.
            // If they are not equal, this will throw an error.
            assert(getValue == setValue, "Value retrieved from Memcache does not match the set value")

            // Cancel all tasks in the task group.
            // This also results in the connection to Memcache being closed.
            group.cancelAll()
        }
    }
}
