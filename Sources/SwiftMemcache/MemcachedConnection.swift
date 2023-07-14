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
    private let host: String
    private let port: Int

    /// Enum representing the current state of the MemcachedConnection.
    ///
    /// The State is either initial, running or finished, depending on whether the connection
    /// to the server is active or has been closed. When running, it contains the properties
    /// for the buffer allocator, request stream, and the stream's continuation.
    private enum State {
        case initial(
            /// The channel's event loop group.
            eventLoopGroup: EventLoopGroup
        )
        case running(
            /// The allocator used to create new buffers.
            bufferAllocator: ByteBufferAllocator,
            /// The underlying channel to communicate with the server.
            channel: NIOAsyncChannel<MemcachedResponse, MemcachedRequest>,
            /// The stream of requests to be sent to the server.
            requestStream: AsyncStream<StreamElement>,
            /// The continuation for the request stream.
            requestContinuation: AsyncStream<StreamElement>.Continuation
        )
        case finished
    }

    /// Enum representing the possible errors that can be encountered in `MemcachedConnection`.
    enum MemcachedConnectionError: Error {
        /// Indicates that the connection has shut down.
        case connectionShutdown
    }

    private var connectionState: State

    /// Initialize a new MemcachedConnection.
    ///
    /// - Parameters:
    ///   - host: The host address of the Memcache server.
    ///   - port: The port number of the Memcache server.
    ///   - eventLoopGroup: The event loop group to use for this connection.
    public init(host: String, port: Int, eventLoopGroup: EventLoopGroup) {
        self.host = host
        self.port = port
        self.connectionState = .initial(eventLoopGroup: eventLoopGroup)
    }

    /// Start consuming the requestStream
    ///
    /// This function starts consuming the requests from the `requestStream`,
    /// sending each request to the Memcache server and handling the server's responses.
    public func run() async throws {
        guard case .initial(let eventLoopGroup) = connectionState else {
            return
        }

        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in
                return channel.pipeline.addHandlers([MessageToByteHandler(MemcachedRequestEncoder()), ByteToMessageHandler(MemcachedResponseDecoder())])
            }

        let rawChannel = try await bootstrap.connect(host: self.host, port: self.port).get()

        let channel = try await eventLoopGroup.next().submit { () -> NIOAsyncChannel<MemcachedResponse, MemcachedRequest> in
            return try NIOAsyncChannel<MemcachedResponse, MemcachedRequest>(synchronouslyWrapping: rawChannel)
        }.get()

        let bufferAllocator = ByteBufferAllocator()
        let (stream, continuation) = AsyncStream<StreamElement>.makeStream()
        self.connectionState = .running(
            bufferAllocator: bufferAllocator,
            channel: channel,
            requestStream: stream,
            requestContinuation: continuation
        )

        var iterator = channel.inboundStream.makeAsyncIterator()
        switch self.connectionState {
        case .running(_, let channel, let requestStream, let requestContinuation):
            for await (request, continuation) in requestStream {
                do {
                    try await channel.outboundWriter.write(request)
                    let responseBuffer = try await iterator.next()

                    if let response = responseBuffer {
                        continuation.resume(returning: response)
                    }
                } catch {
                    switch self.connectionState {
                    case .running:
                        self.connectionState = .finished
                        requestContinuation.finish()
                        continuation.resume(throwing: error)
                    case .initial, .finished:
                        break
                    }
                }
            }
        case .finished, .initial:
            break
        }
    }

    /// Fetch the value for a key from the Memcache server.
    ///
    /// - Parameter key: The key to fetch the value for.
    /// - Returns: A `ByteBuffer` containing the fetched value, or `nil` if no value was found.
    public func get(_ key: String) async throws -> ByteBuffer? {
        guard case .running(_, _, _, let requestContinuation) = self.connectionState else {
            throw MemcachedConnectionError.connectionShutdown
        }

        var flags = MemcachedFlags()
        flags.shouldReturnValue = true
        let command = MemcachedRequest.GetCommand(key: key, flags: flags)
        let request = MemcachedRequest.get(command)

        return try await withCheckedThrowingContinuation { continuation in
            switch requestContinuation.yield((request, continuation)) {
            case .enqueued:
                break
            case .dropped, .terminated:
                continuation.resume(throwing: MemcachedConnectionError.connectionShutdown)
            default:
                break
            }
        }.value
    }

    /// Set the value for a key on the Memcache server.
    ///
    /// - Parameters:
    ///   - key: The key to set the value for.
    ///   - value: The value to set for the key.
    /// - Returns: A `ByteBuffer` containing the server's response to the set request.
    public func set(_ key: String, value: some MemcachedValue) async throws -> ByteBuffer? {
        guard case .running(let bufferAllocator, _, _, let requestContinuation) = self.connectionState else {
            throw MemcachedConnectionError.connectionShutdown
        }

        var buffer = bufferAllocator.buffer(capacity: 0)
        value.writeToBuffer(&buffer)
        let command = MemcachedRequest.SetCommand(key: key, value: buffer)
        let request = MemcachedRequest.set(command)

        return try await withCheckedThrowingContinuation { continuation in
            switch requestContinuation.yield((request, continuation)) {
            case .enqueued:
                break
            case .dropped, .terminated:
                continuation.resume(throwing: MemcachedConnectionError.connectionShutdown)
            default:
                break
            }
        }.value
    }
}
