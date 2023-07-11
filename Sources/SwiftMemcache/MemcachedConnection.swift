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
@_spi(AsyncChannel)

import NIOCore
import NIOPosix

public actor MemcachedConnection {
    private let channel: NIOAsyncChannel<ByteBuffer, ByteBuffer>
    private let bufferAllocator: ByteBufferAllocator
    private let group: MultiThreadedEventLoopGroup
    
    public init(host: String, port: Int, group: MultiThreadedEventLoopGroup) async throws {
            self.group = group
            let bootstrap = ClientBootstrap(group: self.group)
                .channelInitializer { channel in
                    return channel.pipeline.addHandlers([MessageToByteHandler(MemcachedRequestEncoder()), ByteToMessageHandler(MemcachedResponseDecoder())])
                }

            let rawChannel = try await bootstrap.connect(host: host, port: port).get()
            self.channel = try NIOAsyncChannel(synchronouslyWrapping: rawChannel, inboundType: ByteBuffer.self, outboundType: ByteBuffer.self)
        
        self.bufferAllocator = ByteBufferAllocator()
    }


    public func get(_ key: String) async throws -> ByteBuffer? {
        var flags = MemcachedFlags()
        flags.shouldReturnValue = true
        let command = MemcachedRequest.GetCommand(key: key, flags: flags)
        let request = MemcachedRequest.get(command)

        var buffer = self.bufferAllocator.buffer(capacity: 0)
        let encoder = MemcachedRequestEncoder()
        try encoder.encode(data: request, out: &buffer)
        try await self.channel.outboundWriter.write(buffer)

        let responseBuffer = try await self.channel.inboundStream.first(where: { _ in true })
        if responseBuffer == nil || responseBuffer?.readableBytes == 0 {
                fatalError("Received error response from the server.")
        }
        return responseBuffer
    }


    public func set(_ key: String, value: String) async throws -> ByteBuffer? {
        var buffer = self.bufferAllocator.buffer(capacity: value.count)
        buffer.writeString(value)
        let command = MemcachedRequest.SetCommand(key: key, value: buffer)
        let request = MemcachedRequest.set(command)

        var writeBuffer = self.bufferAllocator.buffer(capacity: 0)
        let encoder = MemcachedRequestEncoder()
        try encoder.encode(data: request, out: &writeBuffer)
        try await self.channel.outboundWriter.write(writeBuffer)

        let responseBuffer = try await self.channel.inboundStream.first { _ in true }
        if responseBuffer == nil || responseBuffer?.readableBytes == 0 {
                fatalError("Received error response from the server.")
        }
        return responseBuffer
    }
}
