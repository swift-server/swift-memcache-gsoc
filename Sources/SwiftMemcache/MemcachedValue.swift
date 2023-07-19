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

/// Protocol defining the requirements for a type that can be converted to a ByteBuffer for transmission to Memcached.
public protocol MemcachedValue {
    /// Writes the value to a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer to which the value should be written.
    func writeToBuffer(_ buffer: inout ByteBuffer)

    /// Initializes the type from a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer from which the value should be read.
    static func readFromBuffer(_ buffer: inout ByteBuffer) -> Self?
}

/// Extension for FixedWidthInteger types to conform to MemcachedValue.
extension MemcachedValue where Self: FixedWidthInteger {
    /// Writes the integer to a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer to which the integer should be written.
    public func writeToBuffer(_ buffer: inout ByteBuffer) {
        buffer.reserveCapacity(MemoryLayout<Self>.size)
        buffer.writeInteger(self)
    }

    /// Reads a FixedWidthInteger from a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer from which the value should be read.
    public static func readFromBuffer(_ buffer: inout ByteBuffer) -> Self? {
        return buffer.readInteger()
    }
}

/// Extension for StringProtocol types to conform to MemcachedValue.
extension MemcachedValue where Self: StringProtocol {
    /// Writes the string to a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer to which the string should be written.
    public func writeToBuffer(_ buffer: inout ByteBuffer) {
        buffer.reserveCapacity(buffer.writerIndex + self.count)
        buffer.writeString(String(self))
    }

    /// Reads a String from a ByteBuffer.
    ///
    /// - Parameter buffer: The ByteBuffer from which the value should be read.
    public static func readFromBuffer(_ buffer: inout ByteBuffer) -> Self? {
        guard let string = buffer.readString(length: buffer.readableBytes) else {
            return nil
        }
        return Self(string)
    }
}

/// MemcachedValue conformance to several standard Swift types.
extension Int: MemcachedValue {}
extension Int8: MemcachedValue {}
extension Int16: MemcachedValue {}
extension Int32: MemcachedValue {}
extension Int64: MemcachedValue {}
extension UInt: MemcachedValue {}
extension UInt8: MemcachedValue {}
extension UInt16: MemcachedValue {}
extension UInt32: MemcachedValue {}
extension UInt64: MemcachedValue {}
extension String: MemcachedValue {}
