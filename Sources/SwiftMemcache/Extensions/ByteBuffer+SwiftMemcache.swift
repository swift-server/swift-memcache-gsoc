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
    /// Reads the ASCII representation of a non-negative integer from this buffer.
    /// Whitespace or newline indicates the end of the integer.
    ///
    /// - returns: The integer, or `nil` if there's not enough readable bytes.
    mutating func readIntegerFromASCII() -> UInt64? {
        var value: UInt64 = 0
        while let digit = self.readInteger(as: UInt8.self) {
            switch digit {
            case UInt8(ascii: "0")...UInt8(ascii: "9"):
                value = value * 10 + UInt64(digit - UInt8(ascii: "0"))
            case UInt8.whitespace, UInt8.carriageReturn:
                return value
            default:
                return nil
            }
        }
        return nil
    }
}

extension ByteBuffer {
    /// Writes flags to the ByteBuffer. Iterates over all the flags in MemcachedFlags.
    /// If a flag is set to true, its corresponding byte value and a whitespace character is written into the ByteBuffer.
    ///
    /// - parameters:
    ///     - flags: The MemcachedFlags instance to serialize. This instance holds the flags to be written.
    mutating func writeMemcachedFlags(flags: MemcachedFlags) {
        MemcachedFlags.flagToByte.forEach { keyPath, byte in
            if flags[keyPath: keyPath] == true {
                self.writeInteger(UInt8.whitespace)
                self.writeInteger(byte)
            }
        }
    }
}

extension ByteBuffer {
    /// Read flags from this `ByteBuffer`, moving the reader index forward appropriately.
    ///
    /// - returns: An instance of `MemcachedFlags` containing the flags read from the buffer.
    mutating func readMemcachedFlags() -> MemcachedFlags {
        var flagBytes: Set<UInt8> = []
        while let nextByte = self.readInteger(as: UInt8.self), nextByte != UInt8.whitespace {
            flagBytes.insert(nextByte)
        }
        return MemcachedFlags(flagBytes: flagBytes)
    }
}
