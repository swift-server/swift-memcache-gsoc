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
import XCTest

@testable import Memcache

final class MemcacheIntegrationTest: XCTestCase {
    var channel: ClientBootstrap!
    var group: EventLoopGroup!

    override func setUp() {
        super.setUp()
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.channel = ClientBootstrap(group: self.group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    MessageToByteHandler(MemcacheRequestEncoder()), ByteToMessageHandler(MemcacheResponseDecoder()),
                ])
            }
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.group.syncShutdownGracefully())
        super.tearDown()
    }

    class ResponseHandler: ChannelInboundHandler {
        typealias InboundIn = MemcacheResponse

        let p: EventLoopPromise<MemcacheResponse>

        init(p: EventLoopPromise<MemcacheResponse>) {
            self.p = p
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let response = self.unwrapInboundIn(data)
            self.p.succeed(response)
        }
    }

    func testConnectionToMemcacheServer() throws {
        do {
            let connection = try channel.connect(host: "memcached", port: 11211).wait()
            XCTAssertNotNil(connection)

            // Prepare a MemcacheRequest
            var buffer = ByteBufferAllocator().buffer(capacity: 3)
            buffer.writeString("hi")
            let command = MemcacheRequest.SetCommand(key: "foo", value: buffer)
            let request = MemcacheRequest.set(command)

            // Write the request to the connection
            _ = connection.write(request)

            // Prepare the promise for the response
            let promise = connection.eventLoop.makePromise(of: MemcacheResponse.self)
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
            XCTFail("Failed to connect to Memcache server: \(error)")
        }
    }

    func testMemcacheConnection() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set key and value
            let setValue = "foo"
            try await memcacheConnection.set("bar", value: setValue)

            // Get value for key
            let getValue: String? = try await memcacheConnection.get("bar")
            XCTAssertEqual(getValue, setValue, "Received value should be the same as sent")
            group.cancelAll()
        }
    }

    func testSetValueWithTTL() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set a value for a key.
            let setValue = "foo"
            // Set Time-To-Live Expiration
            let now = ContinuousClock.Instant.now
            let expirationTime = now.advanced(by: .seconds(90))
            let timeToLive = TimeToLive.expiresAt(expirationTime)
            try await memcacheConnection.set("bar", value: setValue, timeToLive: timeToLive)

            // Get value for key
            let getValue: String? = try await memcacheConnection.get("bar")
            XCTAssertEqual(getValue, setValue, "Received value should be the same as sent")

            group.cancelAll()
        }
    }

    func testTouch() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set key and value with a known Time-To-Live
            let setValue = "foo"
            // Initial Time-To-Live in seconds
            let initialTTLValue = 1111
            let now = ContinuousClock.Instant.now
            let expirationTime = now.advanced(by: .seconds(initialTTLValue))
            let timeToLive = TimeToLive.expiresAt(expirationTime)
            try await memcacheConnection.set("bar", value: setValue, timeToLive: timeToLive)

            // Update the Time-To-Live for the key
            // New Time-To-Live in seconds
            let newTTLValue = 2222
            let newExpirationTime = now.advanced(by: .seconds(newTTLValue))
            let newExpiration = TimeToLive.expiresAt(newExpirationTime)
            _ = try await memcacheConnection.touch("bar", newTimeToLive: newExpiration)

            group.cancelAll()
        }
    }

    func testTouchWithIndefiniteExpiration() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set key and value with a known TTL
            let setValue = "foo"
            // Initial Time-To-Live in seconds
            let initialTTLValue = 1
            let now = ContinuousClock.Instant.now
            let expirationTime = now.advanced(by: .seconds(initialTTLValue))
            let timeToLive = TimeToLive.expiresAt(expirationTime)
            try await memcacheConnection.set("bar", value: setValue, timeToLive: timeToLive)

            // Update the Time-To-Live for the key to indefinite
            let newExpiration = TimeToLive.indefinitely
            _ = try await memcacheConnection.touch("bar", newTimeToLive: newExpiration)

            // Wait for more than the initial Time-To-Live duration
            // Sleep for 1.5 seconds
            try await Task.sleep(for: .seconds(1.5))

            // Get the value and make sure it's still there
            let value: String? = try await memcacheConnection.get("bar", as: String.self)
            XCTAssertNotNil(value, "Expected value to exist after TTL expiration time")
            XCTAssertEqual(value, setValue, "Expected value to match set value after TTL expiration time")

            group.cancelAll()
        }
    }

    func testValueWithLongExpiration() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set key and value with a known Time-To-Live
            let setValue = "foo"
            // Initial Time-To-Live in seconds
            // 30 days + 1 seconds
            let initialTTLValue = 60 * 60 * 24 * 30 + 1
            let now = ContinuousClock.Instant.now
            let expirationTime = now.advanced(by: .seconds(initialTTLValue))
            let timeToLive = TimeToLive.expiresAt(expirationTime)
            try await memcacheConnection.set("bar", value: setValue, timeToLive: timeToLive)

            // Sleep for 1.5 seconds
            try await Task.sleep(for: .seconds(1.5))

            // Get the value and make sure it's still there
            let value: String? = try await memcacheConnection.get("bar", as: String.self)
            XCTAssertNotNil(value, "Expected value to exist after waiting for 6 seconds")
            XCTAssertEqual(value, setValue, "Expected value to match set value after waiting for 6 seconds")

            group.cancelAll()
        }
    }

    func testDeleteValue() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set key and value
            let setValue = "foo"
            try await memcacheConnection.set("bar", value: setValue)

            // Delete the key
            do {
                try await memcacheConnection.delete("bar")
            } catch {
                XCTFail("Deletion attempt should be successful, but threw: \(error)")
            }
            group.cancelAll()
        }
    }

    func testPrependValue() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set key and initial value
            let initialValue = "foo"
            try await memcacheConnection.set("greet", value: initialValue)

            // Prepend value to key
            let prependValue = "Hi"
            try await memcacheConnection.prepend("greet", value: prependValue)

            // Get value for key after prepend operation
            let updatedValue: String? = try await memcacheConnection.get("greet")
            XCTAssertEqual(
                updatedValue,
                prependValue + initialValue,
                "Received value should be the same as the concatenation of prependValue and initialValue"
            )

            group.cancelAll()
        }
    }

    func testAppendValue() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set key and initial value
            let initialValue = "hi"
            try await memcacheConnection.set("greet", value: initialValue)

            // Append value to key
            let appendValue = "foo"
            try await memcacheConnection.append("greet", value: appendValue)

            // Get value for key after append operation
            let updatedValue: String? = try await memcacheConnection.get("greet")
            XCTAssertEqual(
                updatedValue,
                initialValue + appendValue,
                "Received value should be the same as the concatenation of initialValue and appendValue"
            )

            group.cancelAll()
        }
    }

    func testAddValue() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Add a value to a key
            let addValue = "foo"

            // Attempt to delete the key, but ignore the error if it doesn't exist
            do {
                try await memcacheConnection.delete("adds")
            } catch let error as MemcacheError where error.code == .keyNotFound {
                // Expected that the key might not exist, so just continue
            } catch {
                XCTFail("Unexpected error during deletion: \(error)")
            }

            // Proceed with adding the key-value pair
            try await memcacheConnection.add("adds", value: addValue)

            // Get value for the key after add operation
            let addedValue: String? = try await memcacheConnection.get("adds")
            XCTAssertEqual(addedValue, addValue, "Received value should be the same as the added value")

            group.cancelAll()
        }
    }

    func testAddValueKeyExists() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Add a value to a key
            let initialValue = "foo"
            let newValue = "bar"

            // Attempt to delete the key, but ignore the error if it doesn't exist
            do {
                try await memcacheConnection.delete("adds")
            } catch let error as MemcacheError {
                switch error.code {
                case .keyNotFound:
                    break
                default:
                    throw error
                }
            }

            // Set an initial value for the key
            try await memcacheConnection.add("adds", value: initialValue)

            do {
                // Attempt to add a new value to the existing key
                try await memcacheConnection.add("adds", value: newValue)
                XCTFail("Expected an error indicating the key exists, but no error was thrown.")
            } catch let error as MemcacheError {
                switch error.code {
                case .keyExist:
                    // Expected error
                    break
                default:
                    XCTFail("Unexpected error: \(error)")
                }
            }

            group.cancelAll()
        }
    }

    func testReplaceValue() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set key and initial value
            let initialValue = "foo"
            try await memcacheConnection.set("greet", value: initialValue)

            // Replace value for the key
            let replaceValue = "hi"
            try await memcacheConnection.replace("greet", value: replaceValue)

            // Get value for the key after replace operation
            let replacedValue: String? = try await memcacheConnection.get("greet")
            XCTAssertEqual(replacedValue, replaceValue, "Received value should be the same as the replaceValue")

            group.cancelAll()
        }
    }

    func testReplaceNonExistentKey() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Ensure the key is clean
            do {
                try await memcacheConnection.delete("nonExistentKey")
            } catch let error as MemcacheError where error.code == .keyNotFound {
                // Expected that the key might not exist, so just continue
            } catch {
                XCTFail("Unexpected error during deletion: \(error)")
                return
            }

            do {
                // Attempt to replace value for a non-existent key
                let replaceValue = "testValue"
                try await memcacheConnection.replace("nonExistentKey", value: replaceValue)
                XCTFail("Expected an error indicating the key was not found, but no error was thrown.")
            } catch let error as MemcacheError {
                switch error.code {
                case .keyNotFound:
                    // Expected error
                    break
                default:
                    XCTFail("Unexpected error: \(error)")
                }
            }

            group.cancelAll()
        }
    }

    func testIncrementValue() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set key and initial value
            let initialValue = 1
            try await memcacheConnection.set("increment", value: initialValue)

            // Increment value
            let incrementAmount = 100
            try await memcacheConnection.increment("increment", amount: incrementAmount)

            // Get new value
            let newValue: Int? = try await memcacheConnection.get("increment")

            // Check if new value is equal to initial value plus increment amount
            XCTAssertEqual(newValue, initialValue + incrementAmount, "Incremented value is incorrect")

            group.cancelAll()
        }
    }

    func testDecrementValue() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set key and initial value
            let initialValue = 100
            try await memcacheConnection.set("decrement", value: initialValue)

            // Increment value
            let decrementAmount = 10
            try await memcacheConnection.decrement("decrement", amount: decrementAmount)

            // Get new value
            let newValue: Int? = try await memcacheConnection.get("decrement")

            // Check if new value is equal to initial value plus increment amount
            XCTAssertEqual(newValue, initialValue - decrementAmount, "Incremented value is incorrect")

            group.cancelAll()
        }
    }

    func testMemcacheConnectionWithUInt() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let memcacheConnection = MemcacheConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await memcacheConnection.run() }

            // Set UInt32 value for key
            let setUInt32Value: UInt32 = 1_234_567_890
            try await memcacheConnection.set("UInt32Key", value: setUInt32Value)

            // Get value for UInt32 key
            let getUInt32Value: UInt32? = try await memcacheConnection.get("UInt32Key")
            XCTAssertEqual(getUInt32Value, setUInt32Value, "Received UInt32 value should be the same as sent")

            // Set UInt64 value for key
            let setUInt64Value: UInt64 = 12_345_678_901_234_567_890
            let _ = try await memcacheConnection.set("UInt64Key", value: setUInt64Value)

            // Get value for UInt64 key
            let getUInt64Value: UInt64? = try await memcacheConnection.get("UInt64Key")
            XCTAssertEqual(getUInt64Value, setUInt64Value, "Received UInt64 value should be the same as sent")

            group.cancelAll()
        }
    }
}
