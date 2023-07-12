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

/// `AsyncStream` extension to facilitate creating an `AsyncStream` along with its corresponding `Continuation`.
///
/// This extension creates an `AsyncStream` and returns it along with its corresponding `Continuation`.
/// A common usage pattern involves yielding requests and a `CheckedContinuation` via `withCheckedThrowingContinuation`
/// to the `AsyncStream`'s `Continuation`.
///
/// - Parameters:
///   - elementType: The type of element that the stream handles. By default, this is the `Element` type that the `AsyncStream` is initialized with.
///   - limit: The buffering limit that the stream should use. By default, this is `.unbounded`.
///
/// - Returns: A tuple containing the created `AsyncStream` and its corresponding `Continuation`.
extension AsyncStream {
    fileprivate static func makeStream(
        of elementType: Element.Type = Element.self,
        bufferingPolicy limit: Continuation.BufferingPolicy = .unbounded
    ) -> (stream: AsyncStream<Element>, continuation: AsyncStream<Element>.Continuation) {
        var continuation: AsyncStream<Element>.Continuation!
        let stream = AsyncStream<Element>(bufferingPolicy: limit) { continuation = $0 }
        return (stream: stream, continuation: continuation!)
    }
}
