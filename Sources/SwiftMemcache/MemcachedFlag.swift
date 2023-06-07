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

enum MemcachedFlag {
    /// v: return item value in <data block>
    case v

    init?(bytes: UInt8) {
        switch bytes {
        case 0x76:
            self = .v
        default:
            return nil
        }
    }

    var bytes: UInt8 {
        switch self {
        case .v:
            return 0x76
        }
    }
}
