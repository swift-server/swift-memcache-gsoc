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
        /// This error is thrown when EOF is encountered but there is still an expected next step
        /// in the decoder's state machine. This error suggests that the message ended prematurely,
        /// possibly indicating a bad message.
        case unexpectedNextStep(NextStep)
        /// This error is thrown when an unexpected character is encountered in the buffer
        /// during the decoding process.
        case unexpectedCharacter(UInt8)
    }

    /// The next step that the decoder will take. The value of this enum determines how the decoder
    /// processes the current state of the ByteBuffer.
    enum NextStep: Hashable {
        /// The initial step.
        case returnCode
        /// Decode the data length
        case dataLength(MemcachedResponse.ReturnCode)
        /// Decode the flags
        case flags(MemcachedResponse.ReturnCode, UInt64?)
        // TODO: Add a next step for decoding the response data if the return code is VA
        case decodeValue(MemcachedResponse.ReturnCode, UInt64, MemcachedFlags?)
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
        while true {
            switch try self.next(buffer: &buffer) {
            case .returnDecodedResponse(let response):
                return response

            case .waitForMoreBytes:
                return nil

            case .continueDecodeLoop:
                ()
            }
        }
    }

    mutating func next(buffer: inout ByteBuffer) throws -> NextDecodeAction {
        switch self.nextStep {
        case .returnCode:
            guard let bytes = buffer.readInteger(as: UInt16.self) else {
                return .waitForMoreBytes
            }

            let returnCode = MemcachedResponse.ReturnCode(bytes)
            self.nextStep = .dataLength(returnCode)
            return .continueDecodeLoop

        case .dataLength(let returnCode):
            if returnCode == .VA {
                // Advance to the first non-whitespace character
                while let currentByte = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self), currentByte == UInt8.whitespace {
                    buffer.moveReaderIndex(forwardBy: 1)
                }

                // Find the index of the next whitespace or carriage return
                guard let endIndex = buffer.readableBytesView.firstIndex(where: { $0 == UInt8.whitespace || $0 == UInt8.carriageReturn }) else {
                    return .waitForMoreBytes
                }

                let lengthString = buffer.readString(length: endIndex - buffer.readerIndex)

                guard let dataLength = UInt64(lengthString!) else {
                    throw MemcachedDecoderError.unexpectedCharacter(buffer.readableBytesView[buffer.readerIndex])
                }

                // Skip over the whitespace or carriage return
                buffer.moveReaderIndex(forwardBy: 1)

                // Check if the next byte is newline and skip it too if it is
                if buffer.getInteger(at: buffer.readerIndex) == UInt8.newline {
                    buffer.moveReaderIndex(forwardBy: 1)
                }

                if buffer.getInteger(at: buffer.readerIndex) == UInt8.whitespace {
                    self.nextStep = .flags(returnCode, dataLength)
                } else {
                    self.nextStep = .decodeValue(returnCode, dataLength, nil)
                }
                return .continueDecodeLoop
            } else {
                self.nextStep = .flags(returnCode, nil)
                return .continueDecodeLoop
            }

        case .flags(let returnCode, let dataLength):
            let flags = buffer.readMemcachedFlags()
            if flags.shouldReturnValue == true {
                self.nextStep = .decodeValue(returnCode, dataLength!, flags)
                return .continueDecodeLoop
            } else {
                let response = MemcachedResponse(returnCode: returnCode, dataLength: dataLength, flags: flags)
                self.nextStep = .returnCode
                return .returnDecodedResponse(response)
            }

        case .decodeValue(let returnCode, let dataLength, let flags):
            guard buffer.readableBytes >= dataLength + 2 else {
                return .waitForMoreBytes
            }

            guard let data = buffer.readSlice(length: Int(dataLength)) else {
                throw MemcachedDecoderError.unexpectedEOF
            }

            guard buffer.readableBytes >= 2,
                  let nextByte = buffer.readInteger(as: UInt8.self),
                  nextByte == UInt8.carriageReturn,
                  let nextNextByte = buffer.readInteger(as: UInt8.self),
                  nextNextByte == UInt8.newline else {
                preconditionFailure("Expected to find CRLF at end of response")
            }

            let response = MemcachedResponse(returnCode: returnCode, dataLength: dataLength, flags: flags, value: data)
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
        case .returnCode:
            return nil
        default:
            throw MemcachedDecoderError.unexpectedNextStep(self.nextStep)
        }
    }
}
