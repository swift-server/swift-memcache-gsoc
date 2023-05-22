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
    mutating func writeIntegerAsASCII<T: FixedWidthInteger>(_ integer: T) {
        let string = String(integer)
        self.writeString(string)
    }
}
