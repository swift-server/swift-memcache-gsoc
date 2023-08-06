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
    var timeToLive: TimeToLive?

    /// Mode for the 'ms' (meta set) command (corresponding to the 'M' flag).
    ///
    /// Represents the mode of the 'ms' command, which determines the behavior of the data operation.
    /// The default mode is 'set'.
    var storageMode: StorageMode?

    init() {}
}

/// Enum representing the Time-To-Live (TTL) of a Memcached value.
public enum TimeToLive: Equatable, Hashable {
    /// The value should never expire.
    case indefinitely
    /// The value should expire after a specified time.
    case expiresAt(ContinuousClock.Instant)
}

/// Enum representing the Memcached 'ms' (meta set) command modes (corresponding to the 'M' flag).
public enum StorageMode: Equatable, Hashable {
    /// The "add" command. If the item exists, LRU is bumped and NS is returned.
    case add
    /// The 'append' command. If the item exists, append the new value to its data.
    case append
    /// The 'prepend' command. If the item exists, prepend the new value to its data.
    case prepend
    /// The "replace" command. The new value is set only if the item already exists.
    case replace
}

extension MemcachedFlags: Hashable {}
