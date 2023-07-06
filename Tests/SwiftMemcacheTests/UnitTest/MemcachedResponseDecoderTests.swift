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
@testable import SwiftMemcache
import XCTest

final class MemcachedResponseDecoderTests: XCTestCase {
    var decoder: MemcachedResponseDecoder!

    override func setUp() {
        super.setUp()
        self.decoder = MemcachedResponseDecoder()
    }

    func makeMemcachedResponseByteBuffer(from response: MemcachedResponse) -> ByteBuffer {
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

            buffer.writeBytes([UInt8.carriageReturn, UInt8.newline])
        }

        return buffer
    }

    func testDecodeResponse(buffer: inout ByteBuffer, expectedReturnCode: MemcachedResponse.ReturnCode) throws {
        // Pass our response through the decoder
        var output: MemcachedResponse? = nil
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
        let storedResponse = MemcachedResponse(returnCode: .HD, dataLength: nil)
        var buffer = self.makeMemcachedResponseByteBuffer(from: storedResponse)
        try self.testDecodeResponse(buffer: &buffer, expectedReturnCode: .HD)
    }

    func testDecodeNotStoredResponse() throws {
        let notStoredResponse = MemcachedResponse(returnCode: .NS, dataLength: nil)
        var buffer = self.makeMemcachedResponseByteBuffer(from: notStoredResponse)
        try self.testDecodeResponse(buffer: &buffer, expectedReturnCode: .NS)
    }

    func testDecodeExistResponse() throws {
        let existResponse = MemcachedResponse(returnCode: .EX, dataLength: nil)
        var buffer = self.makeMemcachedResponseByteBuffer(from: existResponse)
        try self.testDecodeResponse(buffer: &buffer, expectedReturnCode: .EX)
    }

    func testDecodeNotFoundResponse() throws {
        let notFoundResponse = MemcachedResponse(returnCode: .NF, dataLength: nil)
        var buffer = self.makeMemcachedResponseByteBuffer(from: notFoundResponse)
        try self.testDecodeResponse(buffer: &buffer, expectedReturnCode: .NF)
    }

    func testDecodeValueResponse() throws {
        let allocator = ByteBufferAllocator()
        var valueBuffer = allocator.buffer(capacity: 8)
        valueBuffer.writeString("hi")

        let flags = MemcachedFlags()
        let valueResponse = MemcachedResponse(returnCode: .VA, dataLength: 2, flags: flags, value: valueBuffer)
        var buffer = self.makeMemcachedResponseByteBuffer(from: valueResponse)

        // Pass our response through the decoder
        var output: MemcachedResponse? = nil
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
}
