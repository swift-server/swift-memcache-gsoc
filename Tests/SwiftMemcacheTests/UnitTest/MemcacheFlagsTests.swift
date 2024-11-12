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

import XCTest

@testable import Memcache

final class MemcacheFlagsTests: XCTestCase {
    func testVFlag() {
        var flags = MemcacheFlags()
        flags.shouldReturnValue = true
        if let shouldReturnValue = flags.shouldReturnValue {
            XCTAssertTrue(shouldReturnValue)
        } else {
            XCTFail("Flag shouldReturnValue is nil")
        }
    }

    func testTTLFlag() {
        var flags = MemcacheFlags()
        let now = ContinuousClock.Instant.now
        let expirationTime = now.advanced(by: .seconds(60))
        flags.timeToLive = .expiresAt(expirationTime)
        if case .expiresAt(let timeToLive)? = flags.timeToLive {
            XCTAssertEqual(timeToLive, expirationTime)
        } else {
            XCTFail("Flag timeToLive is nil")
        }
    }

    func testStorageModeAdd() {
        var flags = MemcacheFlags()
        flags.storageMode = .add
        if case .add? = flags.storageMode {
            XCTAssertTrue(true)
        } else {
            XCTFail("Flag storageMode is not .add")
        }
    }

    func testStorageModeAppend() {
        var flags = MemcacheFlags()
        flags.storageMode = .append
        if case .append? = flags.storageMode {
            XCTAssertTrue(true)
        } else {
            XCTFail("Flag storageMode is not .append")
        }
    }

    func testStorageModePrepend() {
        var flags = MemcacheFlags()
        flags.storageMode = .prepend
        if case .prepend? = flags.storageMode {
            XCTAssertTrue(true)
        } else {
            XCTFail("Flag storageMode is not .prepend")
        }
    }

    func testStorageModeReplace() {
        var flags = MemcacheFlags()
        flags.storageMode = .replace
        if case .replace? = flags.storageMode {
            XCTAssertTrue(true)
        } else {
            XCTFail("Flag storageMode is not .replace")
        }
    }
}
