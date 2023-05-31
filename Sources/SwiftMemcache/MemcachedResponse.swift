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

struct MemcachedResponse {
    enum ReturnCode {
        case stored
        case notStored
        case exists
        case notFound

        init(_ bytes: UInt16) {
            switch bytes {
            case 0x4844: // "HD"
                self = .stored
            case 0x4E53: // "NS"
                self = .notStored
            case 0x4558: // "EX"
                self = .exists
            case 0x4E46: // "NF"
                self = .notFound
            default:
                preconditionFailure("Unrecognized response code.")
            }
        }
    }

    var returnCode: ReturnCode
    var dataLength: UInt64?
    var flags: [UInt8]
}
