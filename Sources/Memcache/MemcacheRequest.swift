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
public enum MemcacheRequest: Sendable {
    public struct SetCommand: Sendable {
        public let key: String
        public var value: ByteBuffer
        public var flags: MemcacheFlags?

        public init(key: String, value: ByteBuffer, flags: MemcacheFlags? = nil) {
            self.key = key
            self.value = value
            self.flags = flags
        }
    }

    public struct GetCommand: Sendable {
        public let key: String
        public var flags: MemcacheFlags

        public init(key: String, flags: MemcacheFlags) {
            self.key = key
            self.flags = flags
        }
    }

    public struct DeleteCommand: Sendable {
        public let key: String
    }

    public struct ArithmeticCommand: Sendable {
        public let key: String
        public var flags: MemcacheFlags
    }

    case set(SetCommand)
    case get(GetCommand)
    case delete(DeleteCommand)
    case arithmetic(ArithmeticCommand)
}
