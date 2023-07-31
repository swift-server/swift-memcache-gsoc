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

@testable import SwiftMemcache
import XCTest

final class MemcachedFlagsTests: XCTestCase {
    func testVFlag() {
        var flags = MemcachedFlags()
        flags.shouldReturnValue = true
        if let shouldReturnValue = flags.shouldReturnValue {
            XCTAssertTrue(shouldReturnValue)
        } else {
            XCTFail("Flag shouldReturnValue is nil")
        }
    }

    func testTTLFlag() {
        var flags = MemcachedFlags()
        let now = ContinuousClock.Instant.now
        let expirationTime = now.advanced(by: .seconds(60))
        flags.timeToLive = .expiresAt(expirationTime)
        if case .expiresAt(let timeToLive)? = flags.timeToLive {
            XCTAssertEqual(timeToLive, expirationTime)
        } else {
            XCTFail("Flag timeToLive is nil")
        }
    }
}
