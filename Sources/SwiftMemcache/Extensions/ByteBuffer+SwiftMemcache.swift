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
    /// Reads an integer from ASCII characters directly from this `ByteBuffer`.
    /// The reading stops as soon as a non-digit character is encountered.
    ///
    /// - Returns: A `UInt64` integer read from the buffer.
    /// If the buffer does not contain any digits at the current reading position, returns `nil`.
    mutating func readIntegerFromASCII() -> UInt64? {
        var value: UInt64 = 0
        while self.readableBytes > 0, let currentByte = self.readInteger(as: UInt8.self),
              currentByte >= UInt8.zero && currentByte <= UInt8.nine {
            value = (value * 10) + UInt64(currentByte - UInt8.zero)
        }
        return value > 0 ? value : nil
    }
}

extension ByteBuffer {
    /// Serialize and writes MemcachedFlags to the ByteBuffer.
    ///
    /// This method runs a loop over the flags contained in a MemcachedFlags instance.
    /// For each flag that is set to true, its corresponding byte value,
    /// followed by a whitespace character, is added to the ByteBuffer.
    ///
    /// - parameters:
    ///     - flags: An instance of MemcachedFlags that holds the flags intended to be serialized and written to the ByteBuffer.
    mutating func writeMemcachedFlags(flags: MemcachedFlags) {
        if let shouldReturnValue = flags.shouldReturnValue, shouldReturnValue {
            self.writeInteger(UInt8.whitespace)
            self.writeInteger(UInt8.v)
        }
    }
}

extension ByteBuffer {
    /// Parses flags from this `ByteBuffer`, advancing the reader index accordingly.
    ///
    /// - returns: A `MemcachedFlags` instance populated with the flags read from the buffer.
    mutating func readMemcachedFlags() -> MemcachedFlags {
        var flags = MemcachedFlags()
        while let nextByte = self.readInteger(as: UInt8.self) {
            switch nextByte {
            case UInt8.v:
                flags.shouldReturnValue = true
            case UInt8.whitespace:
                continue
            case UInt8.carriageReturn:
                guard let _ = self.readInteger(as: UInt8.self), self.readableBytes > 0 else {
                    break
                }
            default:
                preconditionFailure("Unrecognized flag.")
            }
        }
        return flags
    }
}
