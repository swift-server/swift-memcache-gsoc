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
    private let channel: NIOAsyncChannel<MemcachedResponse, MemcachedRequest>
    /// The channel's event loop group.
    private let eventLoopGroup: EventLoopGroup
    
    /// Enum representing the current state of the MemcachedConnection.
    ///
    /// The ConnectionState is either running or finished, depending on whether the connection
    /// to the server is active or has been closed. When running, it contains the properties
    /// for the buffer allocator, request stream, and the stream's continuation.
    private enum ConnectionState {
        case running(
            /// The allocator used to create new buffers.
            bufferAllocator: ByteBufferAllocator,
            /// The stream of requests to be sent to the server.
            requestStream: AsyncStream<StreamElement>,
            /// The continuation for the request stream.
            requestContinuation: AsyncStream<StreamElement>.Continuation
        )
        case finished
    }
    
    /// Error type thrown by MemcachedConnection when the connection has finished.
    ///
    /// This error is thrown when an attempt is made to perform an operation on
    /// a connection that is no longer active.
    enum MemcachedConnectionError: Error {
        case connectionFinished
    }

    private var connectionState: ConnectionState
    
    /// Initialize a new MemcachedConnection.
    ///
    /// - Parameters:
    ///   - host: The host address of the Memcache server.
    ///   - port: The port number of the Memcache server.
    ///   - eventLoopGroup: The event loop group to use for this connection.
    public init(host: String, port: Int, eventLoopGroup: EventLoopGroup) async throws {
        self.eventLoopGroup = eventLoopGroup
        let bootstrap = ClientBootstrap(group: self.eventLoopGroup)
            .channelInitializer { channel in
                return channel.pipeline.addHandlers([MessageToByteHandler(MemcachedRequestEncoder()), ByteToMessageHandler(MemcachedResponseDecoder())])
            }

        let rawChannel = try await bootstrap.connect(host: host, port: port).get()

        self.channel = try await eventLoopGroup.next().submit { () -> NIOAsyncChannel<MemcachedResponse, MemcachedRequest> in
            return try NIOAsyncChannel<MemcachedResponse, MemcachedRequest>(synchronouslyWrapping: rawChannel)
        }.get()

        let bufferAllocator = ByteBufferAllocator()
        let (stream, continuation) = AsyncStream<StreamElement>.makeStream()
        self.connectionState = .running(
            bufferAllocator: bufferAllocator,
            requestStream: stream,
            requestContinuation: continuation
        )
    }

    /// Start consuming the requestStream
    ///
    /// This function starts consuming the requests from the `requestStream`,
    /// sending each request to the Memcache server and handling the server's responses.
    public func run() async {
        var iterator = self.channel.inboundStream.makeAsyncIterator()
        switch self.connectionState {
        case .running(_, let requestStream, let requestContinuation):
            for await (request, continuation) in requestStream {
                do {
                    try await self.channel.outboundWriter.write(request)
                    let responseBuffer = try await iterator.next()

                    if let response = responseBuffer {
                        continuation.resume(returning: response)
                    }
                } catch {
                    self.connectionState = .finished
                    requestContinuation.finish()
                    continuation.resume(throwing: error)
                }
            }
        case .finished:
            break
        }
    }

    /// Fetch the value for a key from the Memcache server.
    ///
    /// - Parameter key: The key to fetch the value for.
    /// - Returns: A `ByteBuffer` containing the fetched value, or `nil` if no value was found.
    public func get(_ key: String) async throws -> ByteBuffer? {
        guard case .running(_, _, let requestContinuation) = self.connectionState else {
            throw MemcachedConnectionError.connectionFinished
        }
        
        var flags = MemcachedFlags()
        flags.shouldReturnValue = true
        let command = MemcachedRequest.GetCommand(key: key, flags: flags)
        let request = MemcachedRequest.get(command)

        return try await withCheckedThrowingContinuation { continuation in
            requestContinuation.yield((request, continuation))
        }.value
    }

    /// Set the value for a key on the Memcache server.
    ///
    /// - Parameters:
    ///   - key: The key to set the value for.
    ///   - value: The value to set for the key.
    /// - Returns: A `ByteBuffer` containing the server's response to the set request.
    public func set(_ key: String, value: String) async throws -> ByteBuffer? {
        guard case .running(let bufferAllocator, _, let requestContinuation) = self.connectionState else {
            throw MemcachedConnectionError.connectionFinished
        }

        var buffer = bufferAllocator.buffer(capacity: value.count)
        buffer.writeString(value)
        let command = MemcachedRequest.SetCommand(key: key, value: buffer)
        let request = MemcachedRequest.set(command)

        return try await withCheckedThrowingContinuation { continuation in
            requestContinuation.yield((request, continuation))
        }.value
    }
}
