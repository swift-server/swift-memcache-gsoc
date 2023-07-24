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

/// Struct representing the flags of a Memcached command.
///
/// Flags for the 'mg' (meta get) and 'ms' (meta set) commands are represented in this struct.
/// The 'v' flag for the meta get command dictates whether the item value should be returned in the data block.
/// The 'T' flag is used for both the meta get and meta set commands to specify the Time-To-Live (TTL) for an item.
struct MemcachedFlags {
    /// Flag 'v' for the 'mg' (meta get) command.
    ///
    /// If true, the item value is returned in the data block.
    /// If false, the data block for the 'mg' response is optional, and the response code changes from "HD" to "VA <size>".
    var shouldReturnValue: Bool?

    /// Flag 'T' for the 'mg' (meta get) and 'ms' (meta set) commands.
    ///
    /// Represents the Time-To-Live (TTL) for an item, in seconds.
    /// If set, the item is considered to be expired after this number of seconds.
    var timeToLive: UInt32?

    init() {}
}

extension MemcachedFlags: Hashable {}

@available(macOS 13.0, *)
extension MemcachedFlags {
    /// Initializes a new instance of `MemcachedFlags` with a specified expiration time and clock.
    ///
    /// This initializer uses the provided `expiration` and `clock` parameters to calculate the TTL (Time-To-Live)
    /// for an item. The TTL is calculated as the duration from the current time to the expiration time in seconds.
    ///
    /// - Parameters:
    ///   - expiration: The expiration time for the item.
    ///   - clock: The clock used to get the current time.
    init(expiration: ContinuousClock.Instant, clock: ContinuousClock) {
        self.init()
        let now = clock.now
        let timeInterval = now.duration(to: expiration)
        let ttlInSeconds = timeInterval.components.seconds
        self.timeToLive = UInt32(ttlInSeconds)
    }
}
