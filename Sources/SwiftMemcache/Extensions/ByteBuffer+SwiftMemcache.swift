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
    /// Checks if the next two bytes in the buffer are a carriage return and newline.
    /// Does not consume any bytes.
    func isNextEndOfLine() -> Bool {
        return self.readableBytes >= 2 &&
            self.getInteger(at: self.readerIndex, as: UInt8.self) == UInt8.carriageReturn &&
            self.getInteger(at: self.readerIndex + 1, as: UInt8.self) == UInt8.newline
    }

    /// Consumes the next two bytes in the buffer if they are a carriage return and newline.
    /// Returns `true` if the end of line was successfully consumed, `false` otherwise.
    mutating func consumeEndOfLine() -> Bool {
        guard self.isNextEndOfLine() else {
            return false
        }

        self.moveReaderIndex(forwardBy: 2)
        return true
    }
}
