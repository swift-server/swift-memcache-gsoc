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
    /// - returns: The number of bytes written.
    @discardableResult
    @inlinable
    public mutating func writeIntegerAsASCII<T: FixedWidthInteger>(_ integer: T) -> Int {
        let asciiZero = UInt8(ascii: "0")
        var value = integer
        var buffer: ContiguousArray<UInt8> = []
        
        repeat {
            let digit = UInt8(value % 10)
            buffer.insert(asciiZero + digit, at: 0)
            value /= 10
        } while value > 0
        
        let bytesWritten = buffer.count
        self.writeBytes(buffer)
        return bytesWritten
    }
}
