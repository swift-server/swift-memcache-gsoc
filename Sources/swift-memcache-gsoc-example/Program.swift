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

import Logging
import Memcache
import NIOCore
import NIOPosix

@main
struct Program {
    // Use the shared singleton instance of MultiThreadedEventLoopGroup
    static let eventLoopGroup = MultiThreadedEventLoopGroup.singleton
    // Initialize the logger
    static let logger = Logger(label: "memcache")

    static func main() async throws {
        // Instantiate a new MemcacheConnection actor with host, port, and event loop group
        let memcacheConnection = MemcacheConnection(host: "127.0.0.1", port: 11211, eventLoopGroup: eventLoopGroup)

        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add the connection actor's run function to the task group
            // This opens the connection and handles requests until the task is cancelled or the connection is closed
            group.addTask { try await memcacheConnection.run() }

            // Set a value for a key.
            let setValue = "bar"
            try await memcacheConnection.set("foo", value: setValue)

            // Get the value for a key.
            // Specify the expected type for the value returned from Memcache.
            let getValue: String? = try await memcacheConnection.get("foo")

            // Assert that the get operation was successful by comparing the value set and the value returned from Memcache.
            // If they are not equal, this will throw an error.
            assert(getValue == setValue, "Value retrieved from Memcache does not match the set value")

            // Cancel all tasks in the task group.
            // This also results in the connection to Memcache being closed.
            group.cancelAll()
        }
    }
}
