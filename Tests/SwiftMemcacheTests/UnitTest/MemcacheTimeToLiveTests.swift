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
import XCTest

@testable import Memcache

final class MemcacheTimeToLiveTests: XCTestCase {
    let clock = ContinuousClock()

    func testIndefinitelyTTL() {
        let ttl = TimeToLive.indefinitely
        if case .indefinitely = ttl {
            XCTAssertTrue(true, "TTL is indefinite as expected.")
        } else {
            XCTFail("TTL is not indefinite.")
        }
    }

    func testExpiresAtTTL() {
        // 5 seconds in the future
        let future = self.clock.now.advanced(by: .seconds(5))
        let ttl = TimeToLive.expiresAt(future)
        if case .expiresAt(let expirationTime) = ttl {
            XCTAssertTrue(expirationTime == future, "Expiration time is correct.")
        } else {
            XCTFail("TTL expiration time is incorrect.")
        }
    }
}
