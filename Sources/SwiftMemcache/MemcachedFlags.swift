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
/// The 't' flag for the meta get command indicates whether the Time-To-Live (TTL) for the item should be returned.
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

    /// Flag 't' for the 'mg' (meta get) command.
    ///
    /// If true, the Time-To-Live (TTL) for the item is returned.
    /// If false, the TTL for the item is not returned.
    var shouldReturnTTL: Bool?

    init() {}
}

extension MemcachedFlags: Hashable {}

/// Enum representing the Time-To-Live (TTL) of a Memcached value.
@available(macOS 13.0, *)
public enum TimeToLive {
    /// The value should never expire.
    case indefinitely
    /// The value should expire after a specified time.
    case expiresAt(ContinuousClock.Instant)

    /// Returns the duration in seconds between the current time and the expiration time.
    public func durationUntilExpiration(inRelationTo clock: ContinuousClock) -> UInt32 {
        switch self {
        case .indefinitely:
            return 0
        case .expiresAt(let expiration):
            let now = clock.now
            let timeInterval = now.duration(to: expiration)
            return UInt32(timeInterval.components.seconds)
        }
    }
}
