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

public actor MemcachedConnection {
    private let channel: Channel
    
    public init(host: String, port: Int) async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                let promise = channel.eventLoop.makePromise(of: MemcachedResponse.self)
                let responseHandler = ResponseHandler(p: promise)
                return channel.pipeline.addHandlers([MessageToByteHandler(MemcachedRequestEncoder()), ByteToMessageHandler(MemcachedResponseDecoder()), responseHandler])
            }

        self.channel = try await bootstrap.connect(host: host, port: port).get()
    }


    public func get(_ key: String) async throws -> String? {
        // Prepare a MemcachedRequest
        var flags = MemcachedFlags()
        flags.shouldReturnValue = true
        let command = MemcachedRequest.GetCommand(key: key, flags: flags)
        let request = MemcachedRequest.get(command)

        // Write the request to the connection
        try await self.channel.writeAndFlush(request)

        // Wait for the response from the server
        let response = try await self.channel.pipeline.handler(type: ResponseHandler.self).get().p.futureResult.get()

        // Extract the value from the response
        guard response.returnCode == .HD, let data = response.value else {
            return nil
        }
        return data.getString(at: data.readerIndex, length: data.readableBytes)
    }


    public func set(_ key: String, value: String) async throws -> Bool {
        // Prepare a MemcachedRequest
        var buffer = ByteBufferAllocator().buffer(capacity: value.count)
        buffer.writeString(value)
        let command = MemcachedRequest.SetCommand(key: key, value: buffer)
        let request = MemcachedRequest.set(command)

        // Write the request to the connection
        try await self.channel.writeAndFlush(request)

        // Wait for the response from the server
        let response = try await self.channel.pipeline.handler(type: ResponseHandler.self).get().p.futureResult.get()

        // Check the response from the server.
        return response.returnCode == .HD
    }


    // Response handler
    private class ResponseHandler: ChannelInboundHandler {
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
}

