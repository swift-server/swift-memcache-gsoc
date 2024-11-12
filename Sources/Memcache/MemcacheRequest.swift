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

enum MemcacheRequest: Sendable {
    struct SetCommand: Sendable {
        let key: String
        var value: ByteBuffer
        var flags: MemcacheFlags?
    }

    struct GetCommand: Sendable {
        let key: String
        var flags: MemcacheFlags
    }

    struct DeleteCommand: Sendable {
        let key: String
    }

    struct ArithmeticCommand: Sendable {
        let key: String
        var flags: MemcacheFlags
    }

    case set(SetCommand)
    case get(GetCommand)
    case delete(DeleteCommand)
    case arithmetic(ArithmeticCommand)
}
