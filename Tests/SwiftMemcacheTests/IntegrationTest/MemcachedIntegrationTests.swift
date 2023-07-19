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

    func testMemcachedConnectionActor() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer {
            XCTAssertNoThrow(try! group.syncShutdownGracefully())
        }
        let connectionActor = MemcachedConnection(host: "memcached", port: 11211, eventLoopGroup: group)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await connectionActor.run() }

            let setValue = "foo"
            var setBuffer = ByteBufferAllocator().buffer(capacity: setValue.count)
            setBuffer.writeString(setValue)
            let _ = try await connectionActor.set("bar", value: setValue)

            // Get value for key
            let getValue = try await connectionActor.get("bar")
            let getValueString = getValue?.getString(at: getValue!.readerIndex, length: getValue!.readableBytes)
            XCTAssertEqual(getValueString, setValue, "Received value should be the same as sent")

            group.cancelAll()
        }
    }
}
