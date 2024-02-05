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

public struct MemcacheResponse {
    public enum ReturnCode {
        case HD
        case NS
        case EX
        case NF
        case VA
        case EN

        init(_ bytes: UInt16) {
            switch bytes {
            case 0x4844:
                self = .HD
            case 0x4E53:
                self = .NS
            case 0x4558:
                self = .EX
            case 0x4E46:
                self = .NF
            case 0x5641:
                self = .VA
            case 0x454E:
                self = .EN
            default:
                preconditionFailure("Unrecognized response code.")
            }
        }
    }

    public var returnCode: ReturnCode
    public var dataLength: UInt64?
    public var flags: MemcacheFlags?
    public var value: ByteBuffer?
}
