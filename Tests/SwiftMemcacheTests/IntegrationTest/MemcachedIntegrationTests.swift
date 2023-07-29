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
@testable import SwiftMemcache
import XCTest

@available(macOS 13.0, *)
final class MemcachedIntegrationTest: XCTestCase {
    var channel: ClientBootstrap!
    var group: EventLoopGroup!

    override func setUp() {
        super.setUp()
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.channel = ClientBootstrap(group: self.group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return channel.pipeline.addHandlers([MessageToByteHandler(MemcachedRequestEncoder()), ByteToMessageHandler(MemcachedResponseDecoder())])
            }
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.group.syncShutdownGracefully())
        super.tearDown()
    }

    class ResponseHandler: ChannelInboundHandler {
        typealias InboundIn = MemcachedResponse

        let p: EventLoopPromise<MemcachedResponse>

        init(p: EventLoopPromise<MemcachedResponse>) {
            self.p = p
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let response = self.unwrapInboundIn(data)
            self.p.succeed(response)
        }
    }

    func testConnectionToMemcachedServer() throws {
        do {
            let connection = try channel.connect(host: "memcached", port: 11211).wait()
            XCTAssertNotNil(connection)

            // Prepare a MemcachedRequest
            var buffer = ByteBufferAllocator().buffer(capacity: 3)
            buffer.writeString("hi")
            let command = MemcachedRequest.SetCommand(key: "foo", value: buffer)
            let request = MemcachedRequest.set(command)

            // Write the request to the connection
            _ = connection.write(request)

            // Prepare the promise for the response
            let promise = connection.eventLoop.makePromise(of: MemcachedResponse.self)
            let responseHandler = ResponseHandler(p: promise)
            _ = connection.pipeline.addHandler(responseHandler)

            // Flush and then read the response from the server
            connection.flush()
            connection.read()

            // Wait for the promise to be fulfilled
            let response = try promise.futureResult.wait()

            // Check the response from the server.
            print("Response return code: \(response.returnCode)")

        } catch {
            XCTFail("Failed to connect to Memcached server: \(error)")
        }
    }

    @available(macOS 13.0, *)
    func testMemcachedConnection() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let MemcachedConnection = MemcachedConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await MemcachedConnection.run() }

            // Set key and value
            let setValue = "foo"
            try await MemcachedConnection.set("bar", value: setValue)

            // Get value for key
            let getValue: String? = try await MemcachedConnection.get("bar")
            XCTAssertEqual(getValue, setValue, "Received value should be the same as sent")
            group.cancelAll()
        }
    }

    @available(macOS 13.0, *)
    func testSetValueWithTTL() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcachedConnection = MemcachedConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcachedConnection.run() }

            // Set a value for a key.
            let setValue = "foo"
            // Set TTL Expiration
            let now = ContinuousClock.Instant.now
            let expirationTime = now.advanced(by: .seconds(90))
            let expiration = TimeToLive.expiresAt(expirationTime)
            try await memcachedConnection.set("bar", value: setValue, expiration: expiration)

            // Get value for key
            let getValue: String? = try await memcachedConnection.get("bar")
            XCTAssertEqual(getValue, setValue, "Received value should be the same as sent")

            group.cancelAll()
        }
    }

    @available(macOS 13.0, *)
    func testTouch() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcachedConnection = MemcachedConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcachedConnection.run() }

            // Set key and value with a known TTL
            let setValue = "foo"
            // Initial TTL in seconds
            let initialTTLValue = 1111
            let now = ContinuousClock.Instant.now
            let expirationTime = now.advanced(by: .seconds(initialTTLValue))
            let expiration = TimeToLive.expiresAt(expirationTime)
            try await memcachedConnection.set("bar", value: setValue, expiration: expiration)

            // Update the TTL for the key
            // New TTL in seconds
            let newTTLValue = 2222
            let newExpirationTime = now.advanced(by: .seconds(newTTLValue))
            let newExpiration = TimeToLive.expiresAt(newExpirationTime)
            _ = try await memcachedConnection.touch("bar", as: String.self, newTimeToLive: newExpiration)

            group.cancelAll()
        }
    }

    @available(macOS 13.0, *)
    func testTouchWithIndefiniteExpiration() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcachedConnection = MemcachedConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcachedConnection.run() }

            // Set key and value with a known TTL
            let setValue = "foo"
            // Initial TTL in seconds
            let initialTTLValue = 5
            let now = ContinuousClock.Instant.now
            let expirationTime = now.advanced(by: .seconds(initialTTLValue))
            let expiration = TimeToLive.expiresAt(expirationTime)
            try await memcachedConnection.set("bar", value: setValue, expiration: expiration)

            // Update the TTL for the key to indefinite
            let newExpiration = TimeToLive.indefinitely
            _ = try await memcachedConnection.touch("bar", as: String.self, newTimeToLive: newExpiration)

            // Wait for more than the initial TTL duration
            // Sleep for 6 seconds
            try await Task.sleep(nanoseconds: UInt64(6 * 1_000_000_000))

            // Get the value and make sure it's still there
            let value: String? = try await memcachedConnection.get("bar", as: String.self)
            XCTAssertNotNil(value, "Expected value to exist after TTL expiration time")
            XCTAssertEqual(value, setValue, "Expected value to match set value after TTL expiration time")

            group.cancelAll()
        }
    }

    @available(macOS 13.0, *)
    func testValueWithLongExpiration() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcachedConnection = MemcachedConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcachedConnection.run() }

            // Set key and value with a known TTL
            let setValue = "foo"
            // Initial TTL in seconds
            let initialTTLValue = 60 * 60 * 24 * 30 + 5 // 30 days + 5 seconds
            let now = ContinuousClock.Instant.now
            let expirationTime = now.advanced(by: .seconds(initialTTLValue))
            let expiration = TimeToLive.expiresAt(expirationTime)
            try await memcachedConnection.set("bar", value: setValue, expiration: expiration)

            // Wait for 6 seconds
            try await Task.sleep(nanoseconds: UInt64(6 * 1_000_000_000)) // Sleep for 6 seconds

            // Get the value and make sure it's still there
            let value: String? = try await memcachedConnection.get("bar", as: String.self)
            XCTAssertNotNil(value, "Expected value to exist after waiting for 6 seconds")
            XCTAssertEqual(value, setValue, "Expected value to match set value after waiting for 6 seconds")

            group.cancelAll()
        }
    }

    @available(macOS 13.0, *)
    func testMemcachedConnectionWithUInt() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let MemcachedConnection = MemcachedConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await MemcachedConnection.run() }

            // Set UInt32 value for key
            let setUInt32Value: UInt32 = 1_234_567_890
            try await MemcachedConnection.set("UInt32Key", value: setUInt32Value)

            // Get value for UInt32 key
            let getUInt32Value: UInt32? = try await MemcachedConnection.get("UInt32Key")
            XCTAssertEqual(getUInt32Value, setUInt32Value, "Received UInt32 value should be the same as sent")

            // Set UInt64 value for key
            let setUInt64Value: UInt64 = 12_345_678_901_234_567_890
            let _ = try await MemcachedConnection.set("UInt64Key", value: setUInt64Value)

            // Get value for UInt64 key
            let getUInt64Value: UInt64? = try await MemcachedConnection.get("UInt64Key")
            XCTAssertEqual(getUInt64Value, setUInt64Value, "Received UInt64 value should be the same as sent")

            group.cancelAll()
        }
    }
}
