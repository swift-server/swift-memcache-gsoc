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
struct MemcachedResponseDecoder: NIOSingleStepByteToMessageDecoder {
    typealias InboundOut = MemcachedResponse

    /// Describes the errors that can occur during the decoding process.
    enum MemcachedDecoderError: Error {
        /// This error is thrown when EOF is encountered but there are still
        /// readable bytes in the buffer, which can indicate a bad message.
        case unexpectedEOF

        /// This error is thrown when EOF is encountered but the decoder's next step
        /// is not `.none`. This error suggests that the message ended prematurely,
        /// possibly indicating a bad message.
        case unexpectedNextStep(NextStep)
    }

    /// The next step that the decoder will take. The value of this enum determines how the decoder
    /// processes the current state of the ByteBuffer.
    enum NextStep: Hashable {
        /// No further steps are needed, the decoding process is complete for the current message.
        case none
        /// The initial step.
        case returnCode
        /// Decode the data length, flags or check if we are the end
        case dataLengthOrFlag(MemcachedResponse.ReturnCode)
        /// Decode the next flag
        case decodeNextFlag(MemcachedResponse.ReturnCode, UInt64?, [UInt8])
        /// Decode end of line
        case decodeEndOfLine(MemcachedResponse.ReturnCode, UInt64?, [UInt8])
    }

    /// The action that the decoder will take in response to the current state of the ByteBuffer and the `NextStep`.
    enum NextDecodeAction {
        /// We need more bytes to decode the next step.
        case waitForMoreBytes
        /// We can continue decoding.
        case continueDecodeLoop
        /// We have decoded the next response and need to return it.
        case returnDecodedResponse(MemcachedResponse)
    }

    /// The next step in decoding.
    var nextStep: NextStep = .returnCode

    mutating func decode(buffer: inout ByteBuffer) throws -> InboundOut? {
        while self.nextStep != .none {
            switch try self.next(buffer: &buffer) {
            case .returnDecodedResponse(let response):
                return response

            case .waitForMoreBytes:
                return nil

            case .continueDecodeLoop:
                ()
            }
        }
        return nil
    }

    mutating func next(buffer: inout ByteBuffer) throws -> NextDecodeAction {
        switch self.nextStep {
        case .none:
            return .waitForMoreBytes

        case .returnCode:
            guard let bytes = buffer.readInteger(as: UInt16.self) else {
                return .waitForMoreBytes
            }

            let returnCode = MemcachedResponse.ReturnCode(bytes)
            self.nextStep = .dataLengthOrFlag(returnCode)
            return .continueDecodeLoop

        case .dataLengthOrFlag(let returnCode):
            if returnCode == .stored {
                // TODO: Implement decoding of data length
            }

            // Check if the next bytes are \r\n
            if buffer.consumeEndOfLine() {
                let response = MemcachedResponse(returnCode: returnCode, dataLength: nil, flags: [])
                self.nextStep = .returnCode
                return .returnDecodedResponse(response)
            } else {
                self.nextStep = .decodeNextFlag(returnCode, nil, [])
                return .continueDecodeLoop
            }

        case .decodeNextFlag(let returnCode, let dataLength, var flags):
            if let nextByte = buffer.readInteger(as: UInt8.self), nextByte != UInt8.whitespace {
                flags.append(nextByte)
                self.nextStep = .decodeNextFlag(returnCode, dataLength, flags)
                return .continueDecodeLoop
            } else {
                self.nextStep = .decodeEndOfLine(returnCode, dataLength, flags)
                return .continueDecodeLoop
            }

        case .decodeEndOfLine(let returnCode, let dataLength, let flags):
            guard buffer.consumeEndOfLine() else {
                return .waitForMoreBytes
            }

            let response = MemcachedResponse(returnCode: returnCode, dataLength: dataLength, flags: flags)
            self.nextStep = .returnCode
            return .returnDecodedResponse(response)
        }
    }

    mutating func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> MemcachedResponse? {
        // Try to decode what is left in the buffer.
        if let output = try self.decode(buffer: &buffer) {
            return output
        }

        guard buffer.readableBytes == 0 || seenEOF else {
            // If there are still readable bytes left and we haven't seen an EOF
            // then something is wrong with the message or how we called the decoder.
            throw MemcachedDecoderError.unexpectedEOF
        }

        switch self.nextStep {
        case .none, .returnCode:
            return nil
        default:
            throw MemcachedDecoderError.unexpectedNextStep(self.nextStep)
        }
    }
}
