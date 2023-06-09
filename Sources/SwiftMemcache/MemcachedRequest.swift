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

enum MemcachedRequest {
    struct SetCommand {
        let key: String
        var value: ByteBuffer
    }

    struct GetCommand {
        let key: String
        var flags: MemcachedFlags
    }

    case set(SetCommand)
    case get(GetCommand)
}
