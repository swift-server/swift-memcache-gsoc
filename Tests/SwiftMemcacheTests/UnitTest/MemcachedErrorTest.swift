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

final class MemcachedErrorTests: XCTestCase {
    func testInitialization() {
        let location = MemcachedError.SourceLocation(function: "testFunction", file: "testFile.swift", line: 8)

        let error = MemcachedError(code: .keyNotFound, message: "Key not available", cause: nil, location: location)

        XCTAssertEqual(error.code.description, "Key not Found")
        XCTAssertEqual(error.message, "Key not available")
        XCTAssertEqual(error.location.function, "testFunction")
        XCTAssertEqual(error.location.file, "testFile.swift")
        XCTAssertEqual(error.location.line, 8)
    }

    func testCustomStringConvertible() {
        let location = MemcachedError.SourceLocation.here()
        let causeError = MemcachedError(code: .protocolError, message: "No response", cause: nil, location: location)
        let mainError = MemcachedError(code: .connectionShutdown, message: "Connection lost", cause: causeError, location: location)

        let description = mainError.description

        XCTAssertTrue(description.contains(mainError.code.description))
        XCTAssertTrue(description.contains(mainError.message))
        XCTAssertTrue(description.contains(causeError.code.description))
    }

    func testCustomDebugStringConvertible() {
        let location = MemcachedError.SourceLocation.here()
        let error = MemcachedError(code: .keyExist, message: "Key already present", cause: nil, location: location)

        let debugDescription = error.debugDescription

        XCTAssertTrue(debugDescription.contains(error.code.description))
        XCTAssertTrue(debugDescription.contains(error.message))
    }

    func testDetailedDescription() {
        let location = MemcachedError.SourceLocation.here()
        let causeError = MemcachedError(code: .protocolError, message: "No response", cause: nil, location: location)
        let mainError = MemcachedError(code: .connectionShutdown, message: "Connection lost", cause: causeError, location: location)

        let detailedDesc = mainError.detailedDescription()

        XCTAssertTrue(detailedDesc.contains(mainError.code.description))
        XCTAssertTrue(detailedDesc.contains(mainError.message))
        XCTAssertTrue(detailedDesc.contains(causeError.code.description))
        XCTAssertTrue(detailedDesc.contains(causeError.message))
        XCTAssertTrue(detailedDesc.contains(String(describing: location.line)))
        XCTAssertTrue(detailedDesc.contains(location.file))
        XCTAssertTrue(detailedDesc.contains(location.function))
    }

    func testNestedErrorInitialization() {
        let location = MemcachedError.SourceLocation.here()
        let causeError = MemcachedError(code: .keyExist, message: "Key already present", cause: nil, location: location)
        let mainError = MemcachedError(message: "A nested error", wrapping: causeError)

        XCTAssertEqual(mainError.message, "A nested error")

        if let unwrappedCause = mainError.cause as? MemcachedError {
            XCTAssertEqual(unwrappedCause.code, causeError.code)
            XCTAssertEqual(unwrappedCause.message, causeError.message)
            XCTAssertEqual(unwrappedCause.location, causeError.location)
        } else {
            XCTFail("Expected mainError.cause to be of type MemcachedError")
        }
    }
}
