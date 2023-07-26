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
@testable import SwiftMemcache
import XCTest

@available(macOS 13.0, *)
final class MemcachedTimeToLiveTests: XCTestCase {
    let clock = ContinuousClock()

    func testIndefinitelyTTL() {
        let ttl = TimeToLive.indefinitely
        var durationInSeconds: UInt32 = 0
        switch ttl {
        case .indefinitely:
            durationInSeconds = 0
        case .expiresAt(let expirationTime, let ttlClosure):
            durationInSeconds = ttlClosure(expirationTime, self.clock)
        }
        XCTAssertEqual(durationInSeconds, 0, "Indefinite TTL should return a duration of 0.")
    }

    func testExpiresAtTTL() {
        // 5 seconds in the future
        let future = self.clock.now.advanced(by: .seconds(5))
        let ttl = TimeToLive.expiresAt(future)
        var durationInSeconds: UInt32 = 0
        switch ttl {
        case .indefinitely:
            durationInSeconds = 0
        case .expiresAt(let expirationTime, let ttlClosure):
            durationInSeconds = ttlClosure(expirationTime, self.clock)
        }
        XCTAssert(durationInSeconds >= 0 && durationInSeconds <= 5, "Future TTL should return a duration between 0 and 5 seconds.")
    }
}
