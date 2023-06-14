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

extension ByteBuffer {
    /// Write `integer` into this `ByteBuffer` as ASCII digits, without leading zeros, moving the writer index forward appropriately.
    ///
    /// - parameters:
    ///     - integer: The integer to serialize.
    @inlinable
    mutating func writeIntegerAsASCII(_ integer: some FixedWidthInteger) {
        let string = String(integer)
        self.writeString(string)
    }
}

extension ByteBuffer {
    /// Writes flags to the ByteBuffer. Iterates over all the flags in MemcachedFlag.
    /// If a flag is set, its corresponding byte value and a whitespace character is written into the ByteBuffer.
    ///
    /// - parameters:
    ///     - integer: The MemcachedFlag to serialize.
    mutating func write(flags: MemcachedFlags) {
        MemcachedFlags.flagToByte.forEach { keyPath, byte in
            if flags[keyPath: keyPath] {
                self.writeInteger(UInt8.whitespace)
                self.writeInteger(byte)
            }
        }
    }
}
