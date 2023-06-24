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
/// Flags for the 'mg' (meta get) command are represented in this struct.
/// Currently, only the 'v' flag for the meta get command is supported,
/// which dictates whether the item value should be returned in the data block.
struct MemcachedFlags {
    /// Flag 'v' for the 'mg' (meta get) command.
    ///
    /// If true, the item value is returned in the data block.
    /// If false, the data block for the 'mg' response is optional, and the response code changes from "HD" to "VA <size>".
    var shouldReturnValue: Bool?

    /// Maps key paths of this struct to their corresponding flag bytes.
    static let flagToByte: [KeyPath<MemcachedFlags, Bool?>: UInt8] = [
        \MemcachedFlags.shouldReturnValue: 0x76,
    ]

    init() {
        self.shouldReturnValue = nil
    }

    init(flagBytes: Set<UInt8>) {
        for byte in flagBytes {
            switch byte {
            case 0x76:
                self.shouldReturnValue = true
            default:
                preconditionFailure("Unrecognized flag.")
            }
        }
    }
}

extension MemcachedFlags: Equatable {}
extension MemcachedFlags: Hashable {}
