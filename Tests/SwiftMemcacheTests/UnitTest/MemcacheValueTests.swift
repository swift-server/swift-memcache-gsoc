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

@testable import Memcache
import NIOCore
import XCTest

final class MemcacheValueTests: XCTestCase {
    func testMemcacheValueConformance() {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)

        // Test for Int
        let int = 100
        int.writeToBuffer(&buffer)
        let intResult = Int.readFromBuffer(&buffer)
        XCTAssertEqual(intResult, 100)
        buffer.clear()

        // Test for Int8
        let int8: Int8 = 8
        int8.writeToBuffer(&buffer)
        let int8Result = Int8.readFromBuffer(&buffer)
        XCTAssertEqual(int8Result, 8)
        buffer.clear()

        // Test for Int16
        let int16: Int16 = 16
        int16.writeToBuffer(&buffer)
        let int16Result = Int16.readFromBuffer(&buffer)
        XCTAssertEqual(int16Result, 16)
        buffer.clear()

        // Test for Int32
        let int32: Int32 = 32
        int32.writeToBuffer(&buffer)
        let int32Result = Int32.readFromBuffer(&buffer)
        XCTAssertEqual(int32Result, 32)
        buffer.clear()

        // Test for Int64
        let int64: Int64 = 64
        int64.writeToBuffer(&buffer)
        let int64Result = Int64.readFromBuffer(&buffer)
        XCTAssertEqual(int64Result, 64)
        buffer.clear()

        // Test for UInt
        let uint: UInt = 200
        uint.writeToBuffer(&buffer)
        let uintResult = UInt.readFromBuffer(&buffer)
        XCTAssertEqual(uintResult, 200)
        buffer.clear()

        // Test for UInt8
        let uint8: UInt8 = 9
        uint8.writeToBuffer(&buffer)
        let uint8Result = UInt8.readFromBuffer(&buffer)
        XCTAssertEqual(uint8Result, 9)
        buffer.clear()

        // Test for UInt16
        let uint16: UInt16 = 17
        uint16.writeToBuffer(&buffer)
        let uint16Result = UInt16.readFromBuffer(&buffer)
        XCTAssertEqual(uint16Result, 17)
        buffer.clear()

        // Test for UInt32
        let uint32: UInt32 = 33
        uint32.writeToBuffer(&buffer)
        let uint32Result = UInt32.readFromBuffer(&buffer)
        XCTAssertEqual(uint32Result, 33)
        buffer.clear()

        // Test for UInt64
        let uint64: UInt64 = 65
        uint64.writeToBuffer(&buffer)
        let uint64Result = UInt64.readFromBuffer(&buffer)
        XCTAssertEqual(uint64Result, 65)
        buffer.clear()

        // Test for String
        let string = "string"
        string.writeToBuffer(&buffer)
        let stringResult = String.readFromBuffer(&buffer)
        XCTAssertEqual(stringResult, "string")
    }
}
