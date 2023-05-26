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

struct MemcachedResponseDecoder: ByteToMessageDecoder {
    typealias InboundOut = MemcachedResponse

    var cumulationBuffer: ByteBuffer?

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // Ensure the buffer has at least 3 bytes (minimum for a response code and newline)
        guard buffer.readableBytes >= 3 else {
            return .needMoreData
        }

        guard let asciiValue1 = buffer.readInteger(as: UInt8.self),
              let asciiValue2 = buffer.readInteger(as: UInt8.self),
              let responseCode = ResponseStatus(asciiValues: (asciiValue1, asciiValue2)) else {
            preconditionFailure("Response code could not be read.")
        }

        var flags: ByteBuffer?

        // Check if there's a whitespace character, this indicates flags are present
        if buffer.readableBytes > 2, buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) == UInt8.whitespace {
            buffer.moveReaderIndex(forwardBy: 1)

            // -2 for \r\n
            flags = buffer.readSlice(length: buffer.readableBytes - 2)
        }

        guard buffer.readInteger(as: UInt8.self) == UInt8.carriageReturn,
              buffer.readInteger(as: UInt8.self) == UInt8.newline else {
            preconditionFailure("Line ending '\r\n' not found after the flags.")
        }

        let setResponse = MemcachedResponse.SetResponse(status: responseCode, flags: flags)
        context.fireChannelRead(self.wrapInboundOut(.set(setResponse)))
        return .continue
    }

    func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        return try self.decode(context: context, buffer: &buffer)
    }
}
