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

/// Protocol defining the requirements for a type that can be converted to a ByteBuffer for transmission to Memcache.
public protocol MemcacheValue {
    /// Writes the value to a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer to which the value should be written.
    func writeToBuffer(_ buffer: inout ByteBuffer)

    /// Reads the type from a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer from which the value should be read.
    static func readFromBuffer(_ buffer: inout ByteBuffer) -> Self?
}

/// Extension for FixedWidthInteger types to conform to MemcacheValue.
extension MemcacheValue where Self: FixedWidthInteger {
    /// Writes the integer to a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer to which the integer should be written.
    public func writeToBuffer(_ buffer: inout ByteBuffer) {
        buffer.writeIntegerAsASCII(self)
    }

    /// Reads a FixedWidthInteger from a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer from which the value should be read.
    public static func readFromBuffer(_ buffer: inout ByteBuffer) -> Self? {
        buffer.readIntegerFromASCII()
    }
}

/// Extension for StringProtocol types to conform to MemcacheValue.
extension MemcacheValue where Self: StringProtocol {
    /// Writes the string to a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer to which the string should be written.
    public func writeToBuffer(_ buffer: inout ByteBuffer) {
        buffer.writeString(String(self))
    }

    /// Reads a String from a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer from which the value should be read.
    public static func readFromBuffer(_ buffer: inout ByteBuffer) -> Self? {
        buffer.readString(length: buffer.readableBytes) as? Self
    }
}

/// MemcacheValue conformance to several standard Swift types.
extension Int: MemcacheValue {}
extension Int8: MemcacheValue {}
extension Int16: MemcacheValue {}
extension Int32: MemcacheValue {}
extension Int64: MemcacheValue {}
extension UInt: MemcacheValue {}
extension UInt8: MemcacheValue {}
extension UInt16: MemcacheValue {}
extension UInt32: MemcacheValue {}
extension UInt64: MemcacheValue {}
extension String: MemcacheValue {}
