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
import NIOPosix

@available(macOS 13.0, *)
struct MemcachedRequestEncoder: MessageToByteEncoder {
    typealias OutboundIn = MemcachedRequest

    func encode(data: MemcachedRequest, out: inout ByteBuffer) throws {
        switch data {
        case .set(var command):
            precondition(!command.key.isEmpty, "Key must not be empty")

            // write command and key
            out.writeInteger(UInt8.m)
            out.writeInteger(UInt8.s)
            out.writeInteger(UInt8.whitespace)
            out.writeBytes(command.key.utf8)
            out.writeInteger(UInt8.whitespace)

            // write value length
            let length = command.value.readableBytes
            out.writeIntegerAsASCII(length)

            // write separator
            out.writeInteger(UInt8.carriageReturn)
            out.writeInteger(UInt8.newline)

            // write value and end line
            out.writeBuffer(&command.value)
            out.writeInteger(UInt8.carriageReturn)
            out.writeInteger(UInt8.newline)

        case .get(let command):
            precondition(!command.key.isEmpty, "Key must not be empty")

            // write command and key
            out.writeInteger(UInt8.m)
            out.writeInteger(UInt8.g)
            out.writeInteger(UInt8.whitespace)
            out.writeBytes(command.key.utf8)

            // write flags if there are any
            out.writeMemcachedFlags(flags: command.flags)

            // write separator
            out.writeInteger(UInt8.carriageReturn)
            out.writeInteger(UInt8.newline)
        }
    }
}
