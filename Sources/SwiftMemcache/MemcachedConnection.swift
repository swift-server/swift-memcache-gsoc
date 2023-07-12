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

/// An actor to create a connection to a Memcache server.
///
/// This actor can be used to send commands to the server.
public actor MemcachedConnection {
    private typealias StreamElement = (MemcachedRequest, CheckedContinuation<MemcachedResponse, Error>)
    /// The underlying channel to communicate with the server.
    private let channel: NIOAsyncChannel<ByteBuffer, ByteBuffer>
    /// The allocator used to create new buffers.
    private let bufferAllocator: ByteBufferAllocator
    /// The channel's event loop group.
    private let eventLoopGroup: EventLoopGroup
    /// The stream of requests to be sent to the server.
    private let requestStream: AsyncStream<StreamElement>
    /// The continuation for the request stream.
    private let requestContinuation: AsyncStream<StreamElement>.Continuation

    /// Initialize a new MemcachedConnection.
    ///
    /// - Parameters:
    ///   - host: The host address of the Memcache server.
    ///   - port: The port number of the Memcache server.
    ///   - eventLoopGroup: The event loop group to use for this connection.
    public init(host: String, port: Int, eventLoopGroup: EventLoopGroup) async throws {
        print("yes")
        self.eventLoopGroup = eventLoopGroup
        let bootstrap = ClientBootstrap(group: self.eventLoopGroup)
            .channelInitializer { channel in
                return channel.pipeline.addHandlers([MessageToByteHandler(MemcachedRequestEncoder()), ByteToMessageHandler(MemcachedResponseDecoder())])
            }

        let rawChannel = try await bootstrap.connect(host: host, port: port).get()
        self.channel = try NIOAsyncChannel<ByteBuffer, ByteBuffer>(synchronouslyWrapping: rawChannel)
        self.bufferAllocator = ByteBufferAllocator()

        let (stream, continuation) = AsyncStream<StreamElement>.makeStream()
        self.requestStream = stream
        self.requestContinuation = continuation
    }

    /// Start consuming the requestStream
    ///
    /// This function starts consuming the requests from the `requestStream`,
    /// sending each request to the Memcache server and handling the server's responses.
    public func run() async {
        for await (request, continuation) in self.requestStream {
            var buffer = self.bufferAllocator.buffer(capacity: 0)
            let encoder = MemcachedRequestEncoder()
            do {
                try encoder.encode(data: request, out: &buffer)
                try await self.channel.outboundWriter.write(buffer)

                let responseBuffer = try await self.channel.inboundStream.first { _ in true }

                if var responseBuffer, responseBuffer.readableBytes != 0 {
                    var decoder = MemcachedResponseDecoder()
                    let response = try decoder.decode(buffer: &responseBuffer)
                    continuation.resume(returning: response!)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Fetch the value for a key from the Memcache server.
    ///
    /// - Parameter key: The key to fetch the value for.
    /// - Returns: A `ByteBuffer` containing the fetched value, or `nil` if no value was found.
    public func get(_ key: String) async throws -> ByteBuffer? {
        var flags = MemcachedFlags()
        flags.shouldReturnValue = true
        let command = MemcachedRequest.GetCommand(key: key, flags: flags)
        let request = MemcachedRequest.get(command)

        return try await withCheckedThrowingContinuation { continuation in
            self.requestContinuation.yield((request, continuation))
        }.value
    }

    /// Set the value for a key on the Memcache server.
    ///
    /// - Parameters:
    ///   - key: The key to set the value for.
    ///   - value: The value to set for the key.
    /// - Returns: A `ByteBuffer` containing the server's response to the set request.
    public func set(_ key: String, value: String) async throws -> ByteBuffer? {
        var buffer = self.bufferAllocator.buffer(capacity: value.count)
        buffer.writeString(value)
        let command = MemcachedRequest.SetCommand(key: key, value: buffer)
        let request = MemcachedRequest.set(command)

        return try await withCheckedThrowingContinuation { continuation in
            self.requestContinuation.yield((request, continuation))
        }.value
    }
}
