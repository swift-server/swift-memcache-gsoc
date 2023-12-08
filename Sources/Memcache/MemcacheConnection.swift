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

import _ConnectionPoolModule
import NIOCore
import NIOPosix
import ServiceLifecycle

/// An actor to create a connection to a Memcache server.
///
/// This actor can be used to send commands to the server.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
@_spi(ConnectionPool)
public actor MemcacheConnection: Service, PooledConnection {
    public typealias ID = Int
    public let id: ID

    private let closePromise: EventLoopPromise<Void>

    public var closeFuture: EventLoopFuture<Void> {
        return self.closePromise.futureResult
    }

    private typealias StreamElement = (MemcacheRequest, CheckedContinuation<MemcacheResponse, Error>)
    private let host: String
    private let port: Int

    /// Enum representing the current state of the MemcacheConnection.
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
            channel: NIOAsyncChannel<MemcacheResponse, MemcacheRequest>,
            /// The stream of requests to be sent to the server.
            requestStream: AsyncStream<StreamElement>,
            /// The continuation for the request stream.
            requestContinuation: AsyncStream<StreamElement>.Continuation
        )
        case finished
    }

    private var state: State

    /// Initialize a new MemcacheConnection, with an option to specify an ID.
    /// If no ID is provided, a default value is used.
    ///
    /// - Parameters:
    ///   - host: The host address of the Memcache server.
    ///   - port: The port number of the Memcache server.
    ///   - eventLoopGroup: The event loop group to use for this connection.
    ///   - id: The unique identifier for the connection (optional).
    public init(host: String, port: Int, id: ID = 1, eventLoopGroup: EventLoopGroup) {
        self.host = host
        self.port = port
        self.id = id
        let (stream, continuation) = AsyncStream<StreamElement>.makeStream()
        let bufferAllocator = ByteBufferAllocator()
        self.closePromise = eventLoopGroup.next().makePromise(of: Void.self)
        self.state = .initial(eventLoopGroup: eventLoopGroup, bufferAllocator: bufferAllocator, requestStream: stream, requestContinuation: continuation)
    }

    deinit {
        // Fulfill the promise if it has not been fulfilled yet
        closePromise.fail(MemcacheError(code: .connectionShutdown,
                                        message: "MemcacheConnection deinitialized without closing",
                                        cause: nil,
                                        location: .here()))
    }

    /// Closes the connection. This method is responsible for properly shutting down
    /// and cleaning up resources associated with the connection.
    public func close() {
        switch self.state {
        case .running(_, let asyncChannel, _, _):
            asyncChannel.channel.close().cascade(to: self.closePromise)
        default:
            self.closePromise.succeed(())
        }
        self.state = .finished
    }

    /// Registers a closure to be called when the connection is closed.
    /// This is useful for performing cleanup or notification tasks.
    public func onClose(_ closure: @escaping ((any Error)?) -> Void) {
        self.closeFuture.whenComplete { result in
            switch result {
            case .success:
                closure(nil)
            case .failure(let error):
                closure(error)
            }
        }
    }

    /// Runs the Memcache connection.
    ///
    /// This method connects to the Memcache server and starts handling requests. It only returns when the connection
    /// to the server is finished or the task that called this method is cancelled.
    public func run() async throws {
        guard case .initial(let eventLoopGroup, let bufferAllocator, let stream, let continuation) = state else {
            throw MemcacheError(
                code: .connectionShutdown,
                message: "The connection to the Memcache server has been shut down.",
                cause: nil,
                location: .here()
            )
        }

        let channel = try await ClientBootstrap(group: eventLoopGroup)
            .connect(host: self.host, port: self.port)
            .flatMap { channel in
                return channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(MessageToByteHandler(MemcacheRequestEncoder()))
                    try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(MemcacheResponseDecoder()))
                    return try NIOAsyncChannel<MemcacheResponse, MemcacheRequest>(wrappingChannelSynchronously: channel)
                }
            }.get()

        self.state = .running(
            bufferAllocator: bufferAllocator,
            channel: channel,
            requestStream: stream,
            requestContinuation: continuation
        )

        switch self.state {
        case .running(_, let channel, let requestStream, let requestContinuation):
            try await channel.executeThenClose { inbound, outbound in
                var inboundIterator = inbound.makeAsyncIterator()
                for await (request, continuation) in requestStream {
                    do {
                        try await outbound.write(request)
                        let responseBuffer = try await inboundIterator.next()

                        if let response = responseBuffer {
                            continuation.resume(returning: response)
                        } else {
                            self.state = .finished
                            requestContinuation.finish()
                            continuation.resume(throwing: MemcacheError(
                                code: .connectionShutdown,
                                message: "The connection to the Memcache server was unexpectedly closed.",
                                cause: nil,
                                location: .here()
                            ))
                        }
                    } catch {
                        switch self.state {
                        case .running:
                            self.state = .finished
                            requestContinuation.finish()
                            continuation.resume(throwing: MemcacheError(
                                code: .connectionShutdown,
                                message: "The connection to the Memcache server has shut down while processing a request.",
                                cause: error,
                                location: .here()
                            ))
                        case .initial, .finished:
                            break
                        }
                    }
                }
            }

        case .finished, .initial:
            break
        }
    }

    /// Send a request to the Memcache server and returns a `MemcacheResponse`.
    private func sendRequest(_ request: MemcacheRequest) async throws -> MemcacheResponse {
        switch self.state {
        case .initial(_, _, _, let requestContinuation),
             .running(_, _, _, let requestContinuation):

            return try await withCheckedThrowingContinuation { continuation in
                switch requestContinuation.yield((request, continuation)) {
                case .enqueued:
                    break
                case .dropped, .terminated:
                    continuation.resume(throwing: MemcacheError(
                        code: .connectionShutdown,
                        message: "Unable to enqueue request due to the connection being shutdown.",
                        cause: nil,
                        location: .here()
                    ))
                default:
                    break
                }
            }

        case .finished:
            throw MemcacheError(
                code: .connectionShutdown,
                message: "The connection to the Memcache server has been shut down.",
                cause: nil,
                location: .here()
            )
        }
    }

    /// Retrieves the current `ByteBufferAllocator` based on the actor's state.
    ///
    /// - Returns: The current `ByteBufferAllocator` if the state is either `initial` or `running`.
    /// - Throws: A `MemcacheError` if the connection state is `finished`, indicating the connection to the Memcache server has been shut down.
    ///
    /// The method abstracts the state management aspect, providing a convenient way to access the `ByteBufferAllocator` while
    /// ensuring that the actor's state is appropriately checked.
    private func getBufferAllocator() throws -> ByteBufferAllocator {
        switch self.state {
        case .initial(_, let bufferAllocator, _, _),
             .running(let bufferAllocator, _, _, _):
            return bufferAllocator
        case .finished:
            throw MemcacheError(
                code: .connectionShutdown,
                message: "The connection to the Memcache server has been shut down.",
                cause: nil,
                location: .here()
            )
        }
    }

    // MARK: - Fetching Values

    /// Fetch the value for a key from the Memcache server.
    ///
    /// - Parameter key: The key to fetch the value for.
    /// - Returns: A `Value` containing the fetched value, or `nil` if no value was found.
    /// - Throws: A `MemcacheError` that indicates the failure.
    public func get<Value: MemcacheValue>(_ key: String, as valueType: Value.Type = Value.self) async throws -> Value? {
        var flags = MemcacheFlags()
        flags.shouldReturnValue = true

        let command = MemcacheRequest.GetCommand(key: key, flags: flags)
        let request = MemcacheRequest.get(command)

        let response = try await sendRequest(request)

        if var unwrappedResponse = response.value {
            return Value.readFromBuffer(&unwrappedResponse)
        } else {
            throw MemcacheError(
                code: .protocolError,
                message: "Received an unexpected return code \(response.returnCode) for a get request.",
                cause: nil,
                location: .here()
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
    /// - Throws: A `MemcacheError` that indicates the failure.
    public func touch(_ key: String, newTimeToLive: TimeToLive) async throws {
        var flags = MemcacheFlags()
        flags.timeToLive = newTimeToLive

        let command = MemcacheRequest.GetCommand(key: key, flags: flags)
        let request = MemcacheRequest.get(command)

        _ = try await self.sendRequest(request)
    }

    // MARK: - Setting a Value

    /// Sets a value for a specified key in the Memcache server with an optional Time-to-Live (TTL) parameter.
    ///
    /// - Parameters:
    ///   - key: The key for which the value is to be set.
    ///   - value: The `MemcacheValue` to set for the key.
    ///   - expiration: An optional `TimeToLive` value specifying the TTL (Time-To-Live) for the key-value pair.
    ///     If provided, the key-value pair will be removed from the cache after the specified TTL duration has passed.
    ///     If not provided, the key-value pair will persist indefinitely in the cache.
    /// - Throws: A `MemcacheError` that indicates the failure.
    public func set(_ key: String, value: some MemcacheValue, timeToLive: TimeToLive = .indefinitely) async throws {
        switch self.state {
        case .initial(_, let bufferAllocator, _, _),
             .running(let bufferAllocator, _, _, _):

            var buffer = bufferAllocator.buffer(capacity: 0)
            value.writeToBuffer(&buffer)
            var flags: MemcacheFlags?

            flags = MemcacheFlags()
            flags?.timeToLive = timeToLive

            let command = MemcacheRequest.SetCommand(key: key, value: buffer, flags: flags)
            let request = MemcacheRequest.set(command)

            _ = try await self.sendRequest(request)

        case .finished:
            throw MemcacheError(
                code: .connectionShutdown,
                message: "The connection to the Memcache server has been shut down.",
                cause: nil,
                location: .here()
            )
        }
    }

    // MARK: - Deleting a Value

    /// Delete the value for a key from the Memcache server.
    ///
    /// - Parameter key: The key of the item to be deleted.
    /// - Throws: A `MemcacheError` that indicates the failure.
    public func delete(_ key: String) async throws {
        let command = MemcacheRequest.DeleteCommand(key: key)
        let request = MemcacheRequest.delete(command)

        let response = try await sendRequest(request)

        switch response.returnCode {
        case .HD:
            return
        case .NF:
            throw MemcacheError(
                code: .keyNotFound,
                message: "The specified key was not found.",
                cause: nil,
                location: .here()
            )
        default:
            throw MemcacheError(
                code: .protocolError,
                message: "Received an unexpected return code \(response.returnCode) for a delete request.",
                cause: nil,
                location: .here()
            )
        }
    }

    // MARK: - Prepending a Value

    /// Prepend a value to an existing key in the Memcache server.
    ///
    /// - Parameters:
    ///   - key: The key to prepend the value to.
    ///   - value: The `MemcacheValue` to prepend.
    /// - Throws: A `MemcacheError` that indicates the failure.
    public func prepend(_ key: String, value: some MemcacheValue) async throws {
        let bufferAllocator = try getBufferAllocator()

        var buffer = bufferAllocator.buffer(capacity: 0)
        value.writeToBuffer(&buffer)
        var flags: MemcacheFlags

        flags = MemcacheFlags()
        flags.storageMode = .prepend

        let command = MemcacheRequest.SetCommand(key: key, value: buffer, flags: flags)
        let request = MemcacheRequest.set(command)

        _ = try await self.sendRequest(request)
    }

    // MARK: - Appending a Value

    /// Append a value to an existing key in the Memcache server.
    ///
    /// - Parameters:
    ///   - key: The key to append the value to.
    ///   - value: The `MemcacheValue` to append.
    /// - Throws: A `MemcacheError` that indicates the failure.
    public func append(_ key: String, value: some MemcacheValue) async throws {
        let bufferAllocator = try getBufferAllocator()

        var buffer = bufferAllocator.buffer(capacity: 0)
        value.writeToBuffer(&buffer)
        var flags: MemcacheFlags

        flags = MemcacheFlags()
        flags.storageMode = .append

        let command = MemcacheRequest.SetCommand(key: key, value: buffer, flags: flags)
        let request = MemcacheRequest.set(command)

        _ = try await self.sendRequest(request)
    }

    // MARK: - Adding a Value

    /// Adds a new key-value pair in the Memcache server.
    /// The operation will fail if the key already exists.
    ///
    /// - Parameters:
    ///   - key: The key to add the value to.
    ///   - value: The `MemcacheValue` to add.
    /// - Throws: A `MemcacheError` that indicates the failure.
    public func add(_ key: String, value: some MemcacheValue) async throws {
        let bufferAllocator = try getBufferAllocator()

        var buffer = bufferAllocator.buffer(capacity: 0)
        value.writeToBuffer(&buffer)
        var flags: MemcacheFlags

        flags = MemcacheFlags()
        flags.storageMode = .add

        let command = MemcacheRequest.SetCommand(key: key, value: buffer, flags: flags)
        let request = MemcacheRequest.set(command)

        let response = try await sendRequest(request)

        switch response.returnCode {
        case .HD:
            return
        case .NS:
            throw MemcacheError(
                code: .keyExist,
                message: "The specified key already exist.",
                cause: nil,
                location: .here()
            )
        default:
            throw MemcacheError(
                code: .protocolError,
                message: "Received an unexpected return code \(response.returnCode) for a add request.",
                cause: nil,
                location: .here()
            )
        }
    }

    // MARK: - Replacing a Value

    /// Replace the value for an existing key in the Memcache server.
    /// The operation will fail if the key does not exist.
    ///
    /// - Parameters:
    ///   - key: The key to replace the value for.
    ///   - value: The `MemcacheValue` to replace.
    /// - Throws: A `MemcacheError` that indicates the failure.
    public func replace(_ key: String, value: some MemcacheValue) async throws {
        let bufferAllocator = try getBufferAllocator()

        var buffer = bufferAllocator.buffer(capacity: 0)
        value.writeToBuffer(&buffer)
        var flags: MemcacheFlags

        flags = MemcacheFlags()
        flags.storageMode = .replace

        let command = MemcacheRequest.SetCommand(key: key, value: buffer, flags: flags)
        let request = MemcacheRequest.set(command)

        let response = try await sendRequest(request)

        switch response.returnCode {
        case .HD:
            return
        case .NS:
            throw MemcacheError(
                code: .keyNotFound,
                message: "The specified key was not found.",
                cause: nil,
                location: .here()
            )
        default:
            throw MemcacheError(
                code: .protocolError,
                message: "Received an unexpected return code \(response.returnCode) for a replace request.",
                cause: nil,
                location: .here()
            )
        }
    }

    // MARK: - Increment a Value

    /// Increment the value for an existing key in the Memcache server by a specified amount.
    ///
    /// - Parameters:
    ///   - key: The key for the value to increment.
    ///   - amount: The `Int` amount to increment the value by. Must be larger than 0.
    /// - Throws: A `MemcacheError` that indicates the failure.
    public func increment(_ key: String, amount: Int) async throws {
        // Ensure the amount is greater than 0
        precondition(amount > 0, "Amount to increment should be larger than 0")

        var flags = MemcacheFlags()
        flags.arithmeticMode = .increment(amount)

        let command = MemcacheRequest.ArithmeticCommand(key: key, flags: flags)
        let request = MemcacheRequest.arithmetic(command)

        _ = try await self.sendRequest(request)
    }

    // MARK: - Decrement a Value

    /// Decrement the value for an existing key in the Memcache server by a specified amount.
    ///
    /// - Parameters:
    ///   - key: The key for the value to decrement.
    ///   - amount: The `Int` amount to decrement the value by. Must be larger than 0.
    /// - Throws: A `MemcacheError` that indicates the failure.
    public func decrement(_ key: String, amount: Int) async throws {
        // Ensure the amount is greater than 0
        precondition(amount > 0, "Amount to decrement should be larger than 0")

        var flags = MemcacheFlags()
        flags.arithmeticMode = .decrement(amount)

        let command = MemcacheRequest.ArithmeticCommand(key: key, flags: flags)
        let request = MemcacheRequest.arithmetic(command)

        _ = try await self.sendRequest(request)
    }
}
