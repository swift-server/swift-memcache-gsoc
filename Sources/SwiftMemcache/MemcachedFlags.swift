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
@available(macOS 13.0, *)
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

    /// Flag 't' for the 'mg' (meta get) command.
    ///
    /// If true, the Time-To-Live (TTL) for the item is returned.
    /// If false, the TTL for the item is not returned.
    var shouldReturnTTL: Bool?

    init() {}
}

@available(macOS 13.0, *)
extension MemcachedFlags: Hashable {}

/// Enum representing the Time-To-Live (TTL) of a Memcached value.
@available(macOS 13.0, *)
public enum TimeToLive {
    /// The value should never expire.
    case indefinitely
    /// The value should expire after a specified time.
    case expiresAt(ContinuousClock.Instant)
}

/// Struct representing a value along with its Time-To-Live (TTL) in Memcached.
@available(macOS 13.0, *)
public struct ValueAndTimeToLive<Value: MemcachedValue> {
    /// The value fetched from Memcached.
    public var value: Value
    /// The TTL of the fetched value.
    public var ttl: TimeToLive

    /// Initializes a new instance of `ValueAndTimeToLive` with a value and its TTL.
    public init(value: Value, ttl: TimeToLive) {
        self.value = value
        self.ttl = ttl
    }
}

@available(macOS 13.0, *)
extension MemcachedFlags: Equatable {
    static func == (lhs: MemcachedFlags, rhs: MemcachedFlags) -> Bool {
        guard lhs.shouldReturnValue == rhs.shouldReturnValue, lhs.shouldReturnTTL == rhs.shouldReturnTTL else {
            return false
        }
        switch (lhs.timeToLive, rhs.timeToLive) {
        case (.indefinitely?, .indefinitely?), (nil, nil):
            return true
        case (.expiresAt(let lhsInstant)?, .expiresAt(let rhsInstant)?):
            return lhsInstant == rhsInstant
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.shouldReturnValue)
        hasher.combine(self.shouldReturnTTL)
        switch self.timeToLive {
        case .indefinitely:
            hasher.combine("indefinitely")
        case .expiresAt(let instant):
            hasher.combine(instant)
        case .none:
            break
        }
    }
}
