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
import NIOEmbedded
import XCTest

@testable import Memcache

final class MemcacheResponseDecoderTests: XCTestCase {
    var decoder: MemcacheResponseDecoder!

    override func setUp() {
        super.setUp()
        self.decoder = MemcacheResponseDecoder()
    }

    func makeMemcacheResponseByteBuffer(from response: MemcacheResponse) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        var returnCode: UInt16 = 0

        // Convert the return code enum to UInt16 then write it to the buffer.
        switch response.returnCode {
        case .HD:
            returnCode = 0x4844
        case .NS:
            returnCode = 0x4E53
        case .EX:
            returnCode = 0x4558
        case .NF:
            returnCode = 0x4E46
        case .VA:
            returnCode = 0x5641
        case .EN:
            returnCode = 0x454E
        }

        buffer.writeInteger(returnCode)
        buffer.writeInteger(UInt8.whitespace)

        // Write the data length <size> to the buffer.
        if let dataLength = response.dataLength, response.returnCode == .VA {
            buffer.writeIntegerAsASCII(dataLength)
            buffer.writeBytes([UInt8.carriageReturn, UInt8.newline])

            // Write the value <data block> to the buffer if it exists
            if let value = response.value {
                var mutableValue = value
                buffer.writeBuffer(&mutableValue)
            }
        }
        buffer.writeBytes([UInt8.carriageReturn, UInt8.newline])

        return buffer
    }

    func testDecodeResponse(buffer: inout ByteBuffer, expectedReturnCode: MemcacheResponse.ReturnCode) throws {
        // Pass our response through the decoder
        var output: MemcacheResponse? = nil
        do {
            output = try self.decoder.decode(buffer: &buffer)
        } catch {
            XCTFail("Decoding failed with error: \(error)")
        }
        // Check the decoded response
        if let decoded = output {
            XCTAssertEqual(decoded.returnCode, expectedReturnCode)
        } else {
            XCTFail("Failed to decode the inbound response.")
        }
    }

    func testDecodeStoredResponse() throws {
        let storedResponse = MemcacheResponse(returnCode: .HD, dataLength: nil)
        var buffer = self.makeMemcacheResponseByteBuffer(from: storedResponse)
        try self.testDecodeResponse(buffer: &buffer, expectedReturnCode: .HD)
    }

    func testDecodeNotStoredResponse() throws {
        let notStoredResponse = MemcacheResponse(returnCode: .NS, dataLength: nil)
        var buffer = self.makeMemcacheResponseByteBuffer(from: notStoredResponse)
        try self.testDecodeResponse(buffer: &buffer, expectedReturnCode: .NS)
    }

    func testDecodeExistResponse() throws {
        let existResponse = MemcacheResponse(returnCode: .EX, dataLength: nil)
        var buffer = self.makeMemcacheResponseByteBuffer(from: existResponse)
        try self.testDecodeResponse(buffer: &buffer, expectedReturnCode: .EX)
    }

    func testDecodeNotFoundResponse() throws {
        let notFoundResponse = MemcacheResponse(returnCode: .NF, dataLength: nil)
        var buffer = self.makeMemcacheResponseByteBuffer(from: notFoundResponse)
        try self.testDecodeResponse(buffer: &buffer, expectedReturnCode: .NF)
    }

    func testDecodeMissResponse() throws {
        let missResponse = MemcacheResponse(returnCode: .EN, dataLength: nil)
        var buffer = self.makeMemcacheResponseByteBuffer(from: missResponse)
        try self.testDecodeResponse(buffer: &buffer, expectedReturnCode: .EN)
    }

    func testDecodeValueResponse() throws {
        let allocator = ByteBufferAllocator()
        var valueBuffer = allocator.buffer(capacity: 8)
        valueBuffer.writeString("hi")

        let flags = MemcacheFlags()
        let valueResponse = MemcacheResponse(returnCode: .VA, dataLength: 2, flags: flags, value: valueBuffer)
        var buffer = self.makeMemcacheResponseByteBuffer(from: valueResponse)

        // Pass our response through the decoder
        var output: MemcacheResponse? = nil
        do {
            output = try self.decoder.decode(buffer: &buffer)
        } catch {
            XCTFail("Decoding failed with error: \(error)")
        }
        // Check the decoded response
        if let decoded = output {
            XCTAssertEqual(decoded.returnCode, .VA)
            XCTAssertEqual(decoded.dataLength, 2)
            if let value = decoded.value {
                var copiedBuffer = value
                XCTAssertEqual(copiedBuffer.readString(length: Int(decoded.dataLength!)), "hi")
            } else {
                XCTFail("Decoded value was not found.")
            }
        } else {
            XCTFail("Failed to decode the inbound response.")
        }
    }

    func testDecodePartialResponse() throws {
        let allocator = ByteBufferAllocator()
        var valueBuffer = allocator.buffer(capacity: 8)
        valueBuffer.writeString("hi")

        let flags = MemcacheFlags()
        let valueResponse = MemcacheResponse(returnCode: .VA, dataLength: 2, flags: flags, value: valueBuffer)
        let buffer = self.makeMemcacheResponseByteBuffer(from: valueResponse)

        // Split the buffer in two parts, the first of which does not end with "\r\n"
        let splitIndex = buffer.readableBytes - 6
        // VA 2
        var firstPartBuffer = buffer.getSlice(at: buffer.readerIndex, length: splitIndex)!
        // \r\nhi\r\n
        var secondPartBuffer = buffer.getSlice(
            at: buffer.readerIndex + splitIndex,
            length: buffer.readableBytes - splitIndex
        )!

        // Try to decode the first part, which should return .waitForMoreBytes
        switch try self.decoder.next(buffer: &firstPartBuffer) {
        case .waitForMoreBytes:
            break
        default:
            XCTFail("Decoder did not return .waitForMoreBytes for a partial buffer.")
        }

        // Append the rest of thpe response and try decoding again, which should now work
        firstPartBuffer.writeBuffer(&secondPartBuffer)
        do {
            let output = try decoder.decode(buffer: &firstPartBuffer)
            // Verify the decoded response
            XCTAssertEqual(output?.returnCode, .VA)
            XCTAssertEqual(output?.dataLength, 2)
            if let value = output?.value {
                var copiedBuffer = value
                XCTAssertEqual(copiedBuffer.readString(length: Int(output!.dataLength!)), "hi")
            } else {
                XCTFail("Decoded value was not found.")
            }
        } catch {
            XCTFail("Decoding failed with error: \(error)")
        }
    }
}
