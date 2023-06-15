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

struct MemcachedFlags {
    var v: Bool = false

    static let flagToByte: [KeyPath<MemcachedFlags, Bool>: UInt8] = [
        \MemcachedFlags.v: 0x76,
    ]

    init() {
        self.v = false
    }

    init(flagBytes: Set<UInt8>) {
        for byte in flagBytes {
            switch byte {
            case 0x76:
                self.v = true
            default:
                preconditionFailure("Unrecognized flag.")
            }
        }
    }

    var bytes: Set<UInt8> {
        var result = Set<UInt8>()
        for (keyPath, byte) in Self.flagToByte {
            if self[keyPath: keyPath] {
                result.insert(byte)
            }
        }
        return result
    }
}

extension MemcachedFlags: Equatable {
    static func == (lhs: MemcachedFlags, rhs: MemcachedFlags) -> Bool {
        return lhs.v == rhs.v
    }
}

extension MemcachedFlags: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.v)
    }
}
