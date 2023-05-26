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
    var channel: EmbeddedChannel!

    override func setUp() {
        super.setUp()
        self.decoder = MemcachedResponseDecoder()
        self.channel = EmbeddedChannel(handler: ByteToMessageHandler(self.decoder))
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.channel.finish())
    }

    private func testDecodeSetResponse(responseCode: [UInt8], expectedResponseCode: ResponseStatus, expectedFlags: ByteBuffer? = nil) throws {
        // Prepare a response buffer with a response code
        var buffer = ByteBufferAllocator().buffer(capacity: 8)
        buffer.writeBytes(responseCode)

        buffer.writeBytes([UInt8.carriageReturn, UInt8.newline])

        // Pass our response through the decoder
        XCTAssertNoThrow(try self.channel.writeInbound(buffer))

        // Read the decoded response
        if let decoded = try self.channel.readInbound(as: MemcachedResponse.self) {
            switch decoded {
            case .set(let setResponse):
                XCTAssertEqual(setResponse.status, expectedResponseCode)
            }
        } else {
            XCTFail("Failed to decode the inbound response.")
        }
    }

    func testDecodeSetStoredResponse() throws {
        let storedResponseCode = [UInt8(ascii: "H"), UInt8(ascii: "D")]
        try testDecodeSetResponse(responseCode: storedResponseCode, expectedResponseCode: .stored)
    }

    func testDecodeSetNotStoredResponse() throws {
        let notStoredResponseCode = [UInt8(ascii: "N"), UInt8(ascii: "S")]
        try testDecodeSetResponse(responseCode: notStoredResponseCode, expectedResponseCode: .notStored)
    }

    func testDecodeSetExistResponse() throws {
        let existResponseCode = [UInt8(ascii: "E"), UInt8(ascii: "X")]
        try testDecodeSetResponse(responseCode: existResponseCode, expectedResponseCode: .exists)
    }

    func testDecodeSetNotFoundResponse() throws {
        let notFoundResponseCode = [UInt8(ascii: "N"), UInt8(ascii: "F")]
        try testDecodeSetResponse(responseCode: notFoundResponseCode, expectedResponseCode: .notFound)
    }
}
