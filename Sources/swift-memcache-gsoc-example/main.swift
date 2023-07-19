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

// Create an event loop group with a single thread
let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
// Gracefully shutdown the event loop group when it's no longer needed
defer {
    try! group.syncShutdownGracefully()
}

// Instantiate a new MemcachedConnection actor with host, port, and event loop group
let connectionActor = MemcachedConnection(host: "127.0.0.1", port: 11211, eventLoopGroup: group)

// Use of Swift new structured concurrency model to run the connection and perform operations
try await withThrowingTaskGroup(of: Void.self) { group in
    // Add the connection actor's run function to the task group
    // This opens the connection and handles requests until the task is cancelled or the connection is closed
    group.addTask { try await connectionActor.run() }

    // Set a value for a key. This is an async operation so we use "await".
    let setValue = "bar"
    _ = try await connectionActor.set("foo", value: setValue)

    // Get the value for a key. This is also an async operation so we use "await".
    // Specify the expected type for the value returned from Memcache.
    let getValue: String? = try await connectionActor.get("foo")

    // Assert that the get operation was successful by comparing the value set and the value returned from Memcache.
    // If they are not equal, this will throw an error.
    assert(getValue == setValue, "Value retrieved from Memcache does not match the set value")

    // Cancel all tasks in the task group.
    // This also results in the connection to Memcache being closed.
    group.cancelAll()
}
