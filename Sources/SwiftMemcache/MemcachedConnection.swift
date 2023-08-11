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
            eventLoopGroup: EventLoopGroup,
            /// The allocator used to create new buffers.
            bufferAllocator: ByteBufferAllocator,
            /// The stream of requests to be sent to the server.
            requestStream: AsyncStream<StreamElement>,
            /// The continuation for the request stream.
            requestContinuation: AsyncStream<StreamElement>.Continuation
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

    private var state: State

    /// Initialize a new MemcachedConnection.
    ///
    /// - Parameters:
    ///   - host: The host address of the Memcache server.
    ///   - port: The port number of the Memcache server.
    ///   - eventLoopGroup: The event loop group to use for this connection.
    public init(host: String, port: Int, eventLoopGroup: EventLoopGroup) {
        self.host = host
        self.port = port
        let (stream, continuation) = AsyncStream<StreamElement>.makeStream()
        let bufferAllocator = ByteBufferAllocator()
        self.state = .initial(
            eventLoopGroup: eventLoopGroup,
            bufferAllocator: bufferAllocator,
            requestStream: stream,
            requestContinuation: continuation
        )
    }

    /// Runs the Memcache connection.
    ///
    /// This method connects to the Memcache server and starts handling requests. It only returns when the connection
    /// to the server is finished or the task that called this method is cancelled.
    public func run() async throws {
        guard case .initial(let eventLoopGroup, let bufferAllocator, let stream, let continuation) = state else {
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }

        let channel = try await ClientBootstrap(group: eventLoopGroup)
            .connect(host: self.host, port: self.port)
            .flatMap { channel in
                return channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(MessageToByteHandler(MemcachedRequestEncoder()))
                    try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(MemcachedResponseDecoder()))
                    return try NIOAsyncChannel<MemcachedResponse, MemcachedRequest>(synchronouslyWrapping: channel)
                }
            }.get()

        self.state = .running(
            bufferAllocator: bufferAllocator,
            channel: channel,
            requestStream: stream,
            requestContinuation: continuation
        )

        var iterator = channel.inboundStream.makeAsyncIterator()
        switch self.state {
        case .running(_, let channel, let requestStream, let requestContinuation):
            for await (request, continuation) in requestStream {
                do {
                    try await channel.outboundWriter.write(request)
                    let responseBuffer = try await iterator.next()

                    if let response = responseBuffer {
                        continuation.resume(returning: response)
                    }
                } catch {
                    switch self.state {
                    case .running:
                        self.state = .finished
                        requestContinuation.finish()
                        continuation.resume(throwing: MemcachedError(
                            code: .connectionShutdown,
                            message: "The connection to the Memcached server has shut down while processing a request.",
                            cause: error,
                            location: MemcachedError.SourceLocation.here()
                        ))
                    case .initial, .finished:
                        break
                    }
                }
            }

        case .finished, .initial:
            break
        }
    }

    /// Send a request to the Memcached server and returns a `MemcachedResponse`.
    private func sendRequest(_ request: MemcachedRequest) async throws -> MemcachedResponse {
        switch self.state {
        case .initial(_, _, _, let requestContinuation),
             .running(_, _, _, let requestContinuation):

            return try await withCheckedThrowingContinuation { continuation in
                switch requestContinuation.yield((request, continuation)) {
                case .enqueued:
                    break
                case .dropped, .terminated:
                    continuation.resume(throwing: MemcachedError(
                        code: .connectionShutdown,
                        message: "Unable to enqueue request due to the connection being dropped or terminated.",
                        cause: nil,
                        location: MemcachedError.SourceLocation.here()
                    ))
                default:
                    break
                }
            }

        case .finished:
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }
    }

    // MARK: - Fetching Values

    /// Fetch the value for a key from the Memcache server.
    ///
    /// - Parameter key: The key to fetch the value for.
    /// - Returns: A `Value` containing the fetched value, or `nil` if no value was found.
    public func get<Value: MemcachedValue>(_ key: String, as valueType: Value.Type = Value.self) async throws -> Value? {
        switch self.state {
        case .initial(_, _, _, _),
             .running:

            var flags = MemcachedFlags()
            flags.shouldReturnValue = true

            let command = MemcachedRequest.GetCommand(key: key, flags: flags)
            let request = MemcachedRequest.get(command)

            let response = try await sendRequest(request).value

            if var unwrappedResponse = response {
                return Value.readFromBuffer(&unwrappedResponse)
            } else {
                throw MemcachedError(
                    code: .unexpectedNilResponse,
                    message: "Received an unexpected nil response from the Memcached server.",
                    cause: nil,
                    location: MemcachedError.SourceLocation.here()
                )
            }
        case .finished:
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }
    }

    // MARK: - Touch

    /// Update the time-to-live for a key.
    ///
    /// This method changes the expiration time of an existing item without fetching it. If the key does not exist or if the new expiration time is already passed, the operation will not succeed.
    ///
    /// - Parameters:
    ///   - key: The key to update the time-to-live for.
    ///   - newTimeToLive: The new time-to-live.
    /// - Throws: A `MemcachedError` with the code `.connectionShutdown` if the connection to the Memcache server is shut down.
    public func touch(_ key: String, newTimeToLive: TimeToLive) async throws {
        switch self.state {
        case .initial(_, _, _, _),
             .running:

            var flags = MemcachedFlags()
            flags.timeToLive = newTimeToLive

            let command = MemcachedRequest.GetCommand(key: key, flags: flags)
            let request = MemcachedRequest.get(command)

            _ = try await self.sendRequest(request)

        case .finished:
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }
    }

    // MARK: - Setting a Value

    /// Sets a value for a specified key in the Memcache server with an optional Time-to-Live (TTL) parameter.
    ///
    /// - Parameters:
    ///   - key: The key for which the value is to be set.
    ///   - value: The `MemcachedValue` to set for the key.
    ///   - expiration: An optional `TimeToLive` value specifying the TTL (Time-To-Live) for the key-value pair.
    ///     If provided, the key-value pair will be removed from the cache after the specified TTL duration has passed.
    ///     If not provided, the key-value pair will persist indefinitely in the cache.
    /// - Throws: A `MemcachedError` with the code `.connectionShutdown` if the connection to the Memcache server is shut down.
    public func set(_ key: String, value: some MemcachedValue, timeToLive: TimeToLive = .indefinitely) async throws {
        switch self.state {
        case .initial(_, let bufferAllocator, _, _),
             .running(let bufferAllocator, _, _, _):

            var buffer = bufferAllocator.buffer(capacity: 0)
            value.writeToBuffer(&buffer)
            var flags: MemcachedFlags?

            flags = MemcachedFlags()
            flags?.timeToLive = timeToLive

            let command = MemcachedRequest.SetCommand(key: key, value: buffer, flags: flags)
            let request = MemcachedRequest.set(command)

            _ = try await self.sendRequest(request)

        case .finished:
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }
    }

    // MARK: - Deleting a Value

    /// Delete the value for a key from the Memcache server.
    ///
    /// - Parameter key: The key of the item to be deleted.
    /// - Throws: A `MemcachedError` with the code `.connectionShutdown` if the connection to the Memcache server is shut down.
    /// - Throws: A `MemcachedError` with the code `.keyNotFound` if the key was not found.
    /// - Throws: A `MemcachedError` with the code `.unexpectedNilResponse` if an unexpected response code was returned.
    public func delete(_ key: String) async throws {
        switch self.state {
        case .initial(_, _, _, _),
             .running:

            let command = MemcachedRequest.DeleteCommand(key: key)
            let request = MemcachedRequest.delete(command)

            let response = try await sendRequest(request)

            switch response.returnCode {
            case .HD:
                return
            case .NF:
                throw MemcachedError(
                    code: .keyNotFound,
                    message: "The specified key was not found.",
                    cause: nil,
                    location: MemcachedError.SourceLocation.here()
                )
            default:
                throw MemcachedError(
                    code: .unexpectedNilResponse,
                    message: "Received an unexpected nil response from the Memcached server.",
                    cause: nil,
                    location: MemcachedError.SourceLocation.here()
                )
            }

        case .finished:
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }
    }

    // MARK: - Prepending a Value

    /// Prepend a value to an existing key in the Memcache server.
    ///
    /// - Parameters:
    ///   - key: The key to prepend the value to.
    ///   - value: The `MemcachedValue` to prepend.
    /// - Throws: A `MemcachedError` with the code `.connectionShutdown` if the connection to the Memcache server is shut down.
    public func prepend(_ key: String, value: some MemcachedValue) async throws {
        switch self.state {
        case .initial(_, let bufferAllocator, _, _),
             .running(let bufferAllocator, _, _, _):

            var buffer = bufferAllocator.buffer(capacity: 0)
            value.writeToBuffer(&buffer)
            var flags: MemcachedFlags

            flags = MemcachedFlags()
            flags.storageMode = .prepend

            let command = MemcachedRequest.SetCommand(key: key, value: buffer, flags: flags)
            let request = MemcachedRequest.set(command)

            _ = try await self.sendRequest(request)

        case .finished:
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }
    }

    // MARK: - Appending a Value

    /// Append a value to an existing key in the Memcache server.
    ///
    /// - Parameters:
    ///   - key: The key to append the value to.
    ///   - value: The `MemcachedValue` to append.
    /// - Throws: A `MemcachedError` with the code `.connectionShutdown` if the connection to the Memcache server is shut down.
    public func append(_ key: String, value: some MemcachedValue) async throws {
        switch self.state {
        case .initial(_, let bufferAllocator, _, _),
             .running(let bufferAllocator, _, _, _):

            var buffer = bufferAllocator.buffer(capacity: 0)
            value.writeToBuffer(&buffer)
            var flags: MemcachedFlags

            flags = MemcachedFlags()
            flags.storageMode = .append

            let command = MemcachedRequest.SetCommand(key: key, value: buffer, flags: flags)
            let request = MemcachedRequest.set(command)

            _ = try await self.sendRequest(request)

        case .finished:
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }
    }

    // MARK: - Adding a Value

    /// Adds a new key-value pair in the Memcached server.
    /// The operation will fail if the key already exists.
    ///
    /// - Parameters:
    ///   - key: The key to add the value to.
    ///   - value: The `MemcachedValue` to add.
    /// - Throws: A `MemcachedError` with the code `.connectionShutdown` if the connection to the Memcache server is shut down.
    /// - Throws: A `MemcachedError` with the code `.keyExist` if the key already exist.
    /// - Throws: A `MemcachedError` with the code `.unexpectedNilResponse` if an unexpected response code was returned.
    public func add(_ key: String, value: some MemcachedValue) async throws {
        switch self.state {
        case .initial(_, let bufferAllocator, _, _),
             .running(let bufferAllocator, _, _, _):

            var buffer = bufferAllocator.buffer(capacity: 0)
            value.writeToBuffer(&buffer)
            var flags: MemcachedFlags

            flags = MemcachedFlags()
            flags.storageMode = .add

            let command = MemcachedRequest.SetCommand(key: key, value: buffer, flags: flags)
            let request = MemcachedRequest.set(command)

            let response = try await sendRequest(request)

            switch response.returnCode {
            case .HD:
                return
            case .NS:
                throw MemcachedError(
                    code: .keyExist,
                    message: "The specified key already exist.",
                    cause: nil,
                    location: MemcachedError.SourceLocation.here()
                )
            default:
                throw MemcachedError(
                    code: .unexpectedNilResponse,
                    message: "Received an unexpected nil response from the Memcached server.",
                    cause: nil,
                    location: MemcachedError.SourceLocation.here()
                )
            }

        case .finished:
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }
    }

    // MARK: - Replacing a Value

    /// Replace the value for an existing key in the Memcache server.
    /// The operation will fail if the key does not exist.
    ///
    /// - Parameters:
    ///   - key: The key to replace the value for.
    ///   - value: The `MemcachedValue` to replace.
    /// - Throws: A `MemcachedError` with the code `.connectionShutdown` if the connection to the Memcache server is shut down.
    public func replace(_ key: String, value: some MemcachedValue) async throws {
        switch self.state {
        case .initial(_, let bufferAllocator, _, _),
             .running(let bufferAllocator, _, _, _):

            var buffer = bufferAllocator.buffer(capacity: 0)
            value.writeToBuffer(&buffer)
            var flags: MemcachedFlags

            flags = MemcachedFlags()
            flags.storageMode = .replace

            let command = MemcachedRequest.SetCommand(key: key, value: buffer, flags: flags)
            let request = MemcachedRequest.set(command)

            let response = try await sendRequest(request)

            switch response.returnCode {
            case .HD:
                return
            case .NS:
                throw MemcachedError(
                    code: .keyNotFound,
                    message: "The specified key was not found.",
                    cause: nil,
                    location: MemcachedError.SourceLocation.here()
                )
            default:
                throw MemcachedError(
                    code: .unexpectedNilResponse,
                    message: "Received an unexpected nil response from the Memcached server.",
                    cause: nil,
                    location: MemcachedError.SourceLocation.here()
                )
            }

        case .finished:
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }
    }

    // MARK: - Increment a Value

    /// Increment the value for an existing key in the Memcache server by a specified amount.
    ///
    /// - Parameters:
    ///   - key: The key for the value to increment.
    ///   - amount: The `Int` amount to increment the value by. Must be larger than 0.
    /// - Throws: A `MemcachedError` with the code `.connectionShutdown` if the connection to the Memcache server is shut down.
    public func increment(_ key: String, amount: Int) async throws {
        // Ensure the amount is greater than 0
        precondition(amount > 0, "Amount to increment should be larger than 0")

        switch self.state {
        case .initial(_, _, _, _),
             .running:

            var flags = MemcachedFlags()
            flags.arithmeticMode = .increment(amount)

            let command = MemcachedRequest.ArithmeticCommand(key: key, flags: flags)
            let request = MemcachedRequest.arithmetic(command)

            _ = try await self.sendRequest(request)

        case .finished:
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }
    }

    // MARK: - Decrement a Value

    /// Decrement the value for an existing key in the Memcache server by a specified amount.
    ///
    /// - Parameters:
    ///   - key: The key for the value to decrement.
    ///   - amount: The `Int` amount to decrement the value by. Must be larger than 0.
    /// - Throws: A `MemcachedError` with the code `.connectionShutdown` if the connection to the Memcache server is shut down.
    public func decrement(_ key: String, amount: Int) async throws {
        // Ensure the amount is greater than 0
        precondition(amount > 0, "Amount to decrement should be larger than 0")

        switch self.state {
        case .initial(_, _, _, _),
             .running:

            var flags = MemcachedFlags()
            flags.arithmeticMode = .decrement(amount)

            let command = MemcachedRequest.ArithmeticCommand(key: key, flags: flags)
            let request = MemcachedRequest.arithmetic(command)

            _ = try await self.sendRequest(request)

        case .finished:
            throw MemcachedError(
                code: .connectionShutdown,
                message: "The connection to the Memcached server has shut down.",
                cause: nil,
                location: MemcachedError.SourceLocation.here()
            )
        }
    }
}
