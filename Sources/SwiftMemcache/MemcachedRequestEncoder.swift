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
import NIO
import NIOPosix

internal struct MemcachedRequestEncoder: MessageToByteEncoder {
    public typealias OutboundIn = MemcachedRequest

    public func encode(data: MemcachedRequest, out: inout ByteBuffer) throws {
        switch data {
        case .set(let key, var value):
            // write command and key
            out.writeString(data.command)
            out.writeStaticString(" ")
            out.writeString(key)
            out.writeStaticString(" ")

            // write value length
            let length = value.readableBytes
            out.writeIntegerAsASCII(length)

            // write separator
            out.writeStaticString("\r\n")

            // write value and end line
            out.writeBuffer(&value)
            out.writeStaticString("\r\n")
        }
    }
}