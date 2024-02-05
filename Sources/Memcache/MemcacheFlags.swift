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

/// Struct representing the flags of a Memcache command.
///
/// Flags for the 'mg' (meta get) and 'ms' (meta set) commands are represented in this struct.
/// The 'v' flag for the meta get command dictates whether the item value should be returned in the data block.
/// The 'T' flag is used for both the meta get and meta set commands to specify the Time-To-Live (TTL) for an item.
/// The 't' flag for the meta get command indicates whether the Time-To-Live (TTL) for the item should be returned.
public struct MemcacheFlags: Sendable {
    /// Flag 'v' for the 'mg' (meta get) command.
    ///
    /// If true, the item value is returned in the data block.
    /// If false, the data block for the 'mg' response is optional, and the response code changes from "HD" to "VA <size>".
    public var shouldReturnValue: Bool?

    /// Flag 'T' for the 'mg' (meta get) and 'ms' (meta set) commands.
    ///
    /// Represents the Time-To-Live (TTL) for an item, in seconds.
    /// If set, the item is considered to be expired after this number of seconds.
    public var timeToLive: TimeToLive?

    /// Mode for the 'ms' (meta set) command (corresponding to the 'M' flag).
    ///
    /// Represents the mode of the 'ms' command, which determines the behavior of the data operation.
    /// The default mode is 'set'.
    public var storageMode: StorageMode?

    /// Flag 'M' for the 'ma' (meta arithmetic) command.
    ///
    /// Represents the mode of the 'ma' command, which determines the behavior of the arithmetic operation.
    public var arithmeticMode: ArithmeticMode?

    public init(shouldReturnValue: Bool? = nil, timeToLive: TimeToLive? = nil, storageMode: StorageMode? = nil, arithmeticMode: ArithmeticMode? = nil) {
        self.shouldReturnValue = shouldReturnValue
        self.timeToLive = timeToLive
        self.storageMode = storageMode
        self.arithmeticMode = arithmeticMode
    }
}

/// Enum representing the Time-To-Live (TTL) of a Memcache value.
public enum TimeToLive: Sendable, Equatable, Hashable {
    /// The value should never expire.
    case indefinitely
    /// The value should expire after a specified time.
    case expiresAt(ContinuousClock.Instant)
}

/// Enum representing the Memcache 'ms' (meta set) command modes (corresponding to the 'M' flag).
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

/// Enum representing the mode for the 'ma' (meta arithmetic) command in Memcache (corresponding to the 'M' flag).
public enum ArithmeticMode: Equatable, Hashable {
    /// 'increment' command. If applied, it increases the numerical value of the item.
    case increment(Int)
    /// 'decrement' command. If applied, it decreases the numerical value of the item.
    case decrement(Int)
}

extension MemcacheFlags: Hashable {}
