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

extension UInt8 {
    static var whitespace: UInt8 = .init(ascii: " ")
    static var newline: UInt8 = .init(ascii: "\n")
    static var carriageReturn: UInt8 = .init(ascii: "\r")
    static var m: UInt8 = .init(ascii: "m")
    static var s: UInt8 = .init(ascii: "s")
    static var g: UInt8 = .init(ascii: "g")
    static var d: UInt8 = .init(ascii: "d")
    static var a: UInt8 = .init(ascii: "a")
    static var v: UInt8 = .init(ascii: "v")
    static var T: UInt8 = .init(ascii: "T")
    static var M: UInt8 = .init(ascii: "M")
    static var P: UInt8 = .init(ascii: "P")
    static var A: UInt8 = .init(ascii: "A")
    static var E: UInt8 = .init(ascii: "E")
    static var R: UInt8 = .init(ascii: "R")
<<<<<<< HEAD
    static var D: UInt8 = .init(ascii: "D")
=======
>>>>>>> 9ae24ae6c441eaa6db85fab9671433c65de999b4
    static var zero: UInt8 = .init(ascii: "0")
    static var nine: UInt8 = .init(ascii: "9")
    static var increment: UInt8 = .init(ascii: "+")
    static var decrement: UInt8 = .init(ascii: "-")
}
