//
//  File.swift
//  
//
//  Created by Delo on 7/12/23.
//

import NIOCore
@testable import SwiftMemcache
import XCTest

final class MemcachedValueTests: XCTestCase {
    func testMemcachedValueConformance() {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        
        // Test for Int
        let int: Int = 100
        int.writeToBuffer(&buffer)
        let intResult = buffer.readInteger(as: Int.self)
        XCTAssertEqual(intResult, 100)
        buffer.clear()
        
        // Test for Int8
        let int8: Int8 = 8
        int8.writeToBuffer(&buffer)
        let int8Result = buffer.readInteger(as: Int8.self)
        XCTAssertEqual(int8Result, 8)
        buffer.clear()
        
        // Test for Int16
        let int16: Int16 = 16
        int16.writeToBuffer(&buffer)
        let int16Result = buffer.readInteger(as: Int16.self)
        XCTAssertEqual(int16Result, 16)
        buffer.clear()
        
        // Test for Int32
        let int32: Int32 = 32
        int32.writeToBuffer(&buffer)
        let int32Result = buffer.readInteger(as: Int32.self)
        XCTAssertEqual(int32Result, 32)
        buffer.clear()
        
        // Test for Int64
        let int64: Int64 = 64
        int64.writeToBuffer(&buffer)
        let int64Result = buffer.readInteger(as: Int64.self)
        XCTAssertEqual(int64Result, 64)
        buffer.clear()
        
        // Test for UInt
        let uint: UInt = 200
        uint.writeToBuffer(&buffer)
        let uintResult = buffer.readInteger(as: UInt.self)
        XCTAssertEqual(uintResult, 200)
        buffer.clear()
        
        // Test for UInt8
        let uint8: UInt8 = 9
        uint8.writeToBuffer(&buffer)
        let uint8Result = buffer.readInteger(as: UInt8.self)
        XCTAssertEqual(uint8Result, 9)
        buffer.clear()
        
        // Test for UInt16
        let uint16: UInt16 = 17
        uint16.writeToBuffer(&buffer)
        let uint16Result = buffer.readInteger(as: UInt16.self)
        XCTAssertEqual(uint16Result, 17)
        buffer.clear()
        
        // Test for UInt32
        let uint32: UInt32 = 33
        uint32.writeToBuffer(&buffer)
        let uint32Result = buffer.readInteger(as: UInt32.self)
        XCTAssertEqual(uint32Result, 33)
        buffer.clear()
        
        // Test for UInt64
        let uint64: UInt64 = 65
        uint64.writeToBuffer(&buffer)
        let uint64Result = buffer.readInteger(as: UInt64.self)
        XCTAssertEqual(uint64Result, 65)
        buffer.clear()
        
        // Test for String
        let string: String = "string"
        string.writeToBuffer(&buffer)
        let stringResult = buffer.readString(length: buffer.readableBytes)
        XCTAssertEqual(stringResult, "string")
    }
}

