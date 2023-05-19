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


import XCTest
import NIOCore
import NIO
@testable import SwiftMemcache

final class MemcachedRequestEncoderTests: XCTestCase {
    
    var encoder: MemcachedRequestEncoder!

    override func setUp() {
        super.setUp()
        encoder = MemcachedRequestEncoder()
    }
    
    // set request:
    //  ms foo 2\r\n
    //  hi\r\n
    func testEncodeSetRequest() {
        var buffer = ByteBufferAllocator().buffer(capacity: 2)
        buffer.writeString("hi")

        let request = MemcachedRequest.set(key: "foo", value: buffer)
        
        var outBuffer = ByteBufferAllocator().buffer(capacity: 0)
        
        do {
            try encoder.encode(data: request, out: &outBuffer)
        } catch {
            XCTFail("Encoding failed with error: \(error)")
        }

        let expectedEncodedData = "ms foo 2\r\nhi\r\n"
        XCTAssertEqual(outBuffer.getString(at: 0, length: outBuffer.readableBytes), expectedEncodedData)
    }
}