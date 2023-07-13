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

public protocol MemcachedValue {
    func writeToBuffer(_ buffer: inout ByteBuffer)
}

extension MemcachedValue where Self: FixedWidthInteger {
    public func writeToBuffer(_ buffer: inout ByteBuffer) {
        buffer.writeInteger(self)
    }
}

extension MemcachedValue where Self: StringProtocol {
    public func writeToBuffer(_ buffer: inout ByteBuffer) {
        buffer.writeString(String(self))
    }
}

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
