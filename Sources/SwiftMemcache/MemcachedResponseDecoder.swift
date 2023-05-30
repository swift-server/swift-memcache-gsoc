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

struct MemcachedResponseDecoder: NIOSingleStepByteToMessageDecoder {
    /// Responses look like:
    ///
    /// <RC> <datalen*> <flag1> <flag2> <...>\r\n
    ///
    /// Where <RC> is a 2 character return code. The number of flags returned are
    /// based off of the flags supplied.
    ///
    /// <datalen> is only for responses with payloads, with the return code 'VA'.
    ///
    /// Flags are single character codes, ie 'q' or 'k' or 'I', which adjust the
    /// behavior of the command. If a flag requests a response flag (ie 't' for TTL
    /// remaining), it is returned in the same order as they were in the original
    /// command, though this is not strict.
    ///
    /// Flags are single character codes, ie 'q' or 'k' or 'O', which adjust the
    /// behavior of a command. Flags may contain token arguments, which come after the
    /// flag and before the next space or newline, ie 'Oopaque' or 'Kuserkey'. Flags
    /// can return new data or reflect information, in the same order they were
    /// supplied in the request. Sending an 't' flag with a get for an item with 20
    /// seconds of TTL remaining, would return 't20' in the response.
    ///
    /// All commands accept a tokens 'P' and 'L' which are completely ignored. The
    /// arguments to 'P' and 'L' can be used as hints or path specifications to a
    /// proxy or router inbetween a client and a memcached daemon. For example, a
    /// client may prepend a "path" in the key itself: "mg /path/foo v" or in a proxy
    /// token: "mg foo Lpath/ v" - the proxy may then optionally remove or forward the
    /// token to a memcached daemon, which will ignore them.
    ///
    /// Syntax errors are handled the same as noted under 'Error strings' section
    /// below.
    ///
    /// For usage examples beyond basic syntax, please see the wiki:
    /// https://github.com/memcached/memcached/wiki/MetaCommands
    typealias InboundOut = MemcachedResponse

    func decode(buffer: inout ByteBuffer) throws -> InboundOut? {
        // Ensure the buffer has at least 3 bytes (minimum for a response code and newline)
        guard buffer.readableBytes >= 3 else {
            return nil // Need more data
        }

        // Read the first two characters
        guard let firstReturnCode = buffer.readInteger(as: UInt8.self),
              let secondReturnCode = buffer.readInteger(as: UInt8.self) else {
            preconditionFailure("Response code could not be read.")
        }

        let returnCode = MemcachedResponse.ReturnCode(
            UInt16(firstReturnCode) << 8 | UInt16(secondReturnCode)
        )

        // If there is not a whitespace, then we are at the end of the line.
        guard buffer.readableBytes > 0, let nextByte = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
            return nil // Need more dat
        }

        if nextByte != UInt8.whitespace {
            // We're at the end of the line
            buffer.moveReaderIndex(forwardBy: 1)
        } else {
            // We have additional data or flags to read
            buffer.moveReaderIndex(forwardBy: 1)

            // Assert that we really read \r\n
            guard buffer.readableBytes >= 2,
                  buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) == UInt8.carriageReturn,
                  buffer.getInteger(at: buffer.readerIndex + 1, as: UInt8.self) == UInt8.newline else {
                preconditionFailure("Response ending '\r\n' not found.")
            }

            buffer.moveReaderIndex(forwardBy: 2)
        }

        return MemcachedResponse(returnCode: returnCode)
    }

    func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> InboundOut? {
        return try self.decode(buffer: &buffer)
    }
}
