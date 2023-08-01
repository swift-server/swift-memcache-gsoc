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
@testable import SwiftMemcache
import XCTest

final class MemcachedRequestEncoderTests: XCTestCase {
    var encoder: MemcachedRequestEncoder!

    override func setUp() {
        super.setUp()
        self.encoder = MemcachedRequestEncoder()
    }

    func testEncodeSetRequest() {
        // Prepare a MemcachedRequest
        var buffer = ByteBufferAllocator().buffer(capacity: 2)
        buffer.writeString("hi")
        let command = MemcachedRequest.SetCommand(key: "foo", value: buffer)
        let request = MemcachedRequest.set(command)

        // pass our request through the encoder
        var outBuffer = ByteBufferAllocator().buffer(capacity: 0)
        do {
            try self.encoder.encode(data: request, out: &outBuffer)
        } catch {
            XCTFail("Encoding failed with error: \(error)")
        }

        let expectedEncodedData = "ms foo 2\r\nhi\r\n"
        XCTAssertEqual(outBuffer.getString(at: 0, length: outBuffer.readableBytes), expectedEncodedData)
    }

    func testEncodeTouchRequest() {
        // Prepare a MemcachedRequest
        var flags = MemcachedFlags()

        let clock = ContinuousClock()
        flags.timeToLive = .expiresAt(clock.now.advanced(by: Duration.seconds(90)))
        let command = MemcachedRequest.GetCommand(key: "foo", flags: flags)
        let request = MemcachedRequest.get(command)

        // pass our request through the encoder
        var outBuffer = ByteBufferAllocator().buffer(capacity: 0)
        do {
            try self.encoder.encode(data: request, out: &outBuffer)
        } catch {
            XCTFail("Encoding failed with error: \(error)")
        }

        let expectedEncodedData = "mg foo T89\r\n"
        XCTAssertEqual(outBuffer.getString(at: 0, length: outBuffer.readableBytes), expectedEncodedData)
    }

    func testEncodeLargeInstantRequest() {
        // Prepare a MemcachedRequest
        var flags = MemcachedFlags()

        let clock = ContinuousClock()
        // 45 days
        flags.timeToLive = .expiresAt(clock.now.advanced(by: Duration.seconds(60 * 60 * 24 * 45)))
        let command = MemcachedRequest.GetCommand(key: "foo", flags: flags)
        let request = MemcachedRequest.get(command)

        // pass our request through the encoder
        var outBuffer = ByteBufferAllocator().buffer(capacity: 0)
        do {
            try self.encoder.encode(data: request, out: &outBuffer)
        } catch {
            XCTFail("Encoding failed with error: \(error)")
        }

        // Time-To-Live has been transformed to a Unix timestamp
        var timespec = timespec()
        timespec_get(&timespec, TIME_UTC)
        let timeIntervalNow = Double(timespec.tv_sec) + Double(timespec.tv_nsec) / 1_000_000_000
        let ttlSeconds = Duration.seconds(60 * 60 * 24 * 45).components.seconds
        let ttlUnixTime = Int32(timeIntervalNow) + Int32(ttlSeconds)

        // Extract the encoded Time-To-Live
        let encodedString = outBuffer.getString(at: 0, length: outBuffer.readableBytes)!
        let regex = try! NSRegularExpression(pattern: "T(\\d+)", options: .caseInsensitive)
        let match = regex.firstMatch(in: encodedString, options: [], range: NSRange(location: 0, length: encodedString.utf16.count))
        let encodedTTLRange = Range(match!.range(at: 1), in: encodedString)!
        let encodedTTL = Int32(encodedString[encodedTTLRange])!

        // Check if the encoded ttl is within 5 seconds of the expected value
        XCTAssert(abs(ttlUnixTime - encodedTTL) <= 5, "Encoded TTL is not within 5 seconds of the expected value")
    }

    func testEncodeIndefinitelyRequest() {
        // Prepare a MemcachedRequest
        var flags = MemcachedFlags()

        flags.timeToLive = .indefinitely
        let command = MemcachedRequest.GetCommand(key: "foo", flags: flags)
        let request = MemcachedRequest.get(command)

        // pass our request through the encoder
        var outBuffer = ByteBufferAllocator().buffer(capacity: 0)
        do {
            try self.encoder.encode(data: request, out: &outBuffer)
        } catch {
            XCTFail("Encoding failed with error: \(error)")
        }

        let expectedEncodedData = "mg foo T0\r\n"
        XCTAssertEqual(outBuffer.getString(at: 0, length: outBuffer.readableBytes), expectedEncodedData)
    }

    func testEncodeGetRequest() {
        // Prepare a MemcachedRequest
        var flags = MemcachedFlags()
        flags.shouldReturnValue = true
        let command = MemcachedRequest.GetCommand(key: "foo", flags: flags)

        let request = MemcachedRequest.get(command)

        // Pass our request through the encoder
        var outBuffer = ByteBufferAllocator().buffer(capacity: 0)
        do {
            try self.encoder.encode(data: request, out: &outBuffer)
        } catch {
            XCTFail("Encoding failed with error: \(error)")
        }

        let expectedEncodedData = "mg foo v\r\n"
        XCTAssertEqual(outBuffer.getString(at: 0, length: outBuffer.readableBytes), expectedEncodedData)
    }
}
