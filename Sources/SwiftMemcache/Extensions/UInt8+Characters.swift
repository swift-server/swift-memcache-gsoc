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
    static let whitespace: UInt8 = .init(ascii: " ")
    static let newline: UInt8 = .init(ascii: "\n")
    static let carriageReturn: UInt8 = .init(ascii: "\r")
    static let m: UInt8 = .init(ascii: "m")
    static let s: UInt8 = .init(ascii: "s")
    static let g: UInt8 = .init(ascii: "g")
    static let d: UInt8 = .init(ascii: "d")
    static let a: UInt8 = .init(ascii: "a")
    static let v: UInt8 = .init(ascii: "v")
    static let T: UInt8 = .init(ascii: "T")
    static let M: UInt8 = .init(ascii: "M")
    static let P: UInt8 = .init(ascii: "P")
    static let A: UInt8 = .init(ascii: "A")
    static let E: UInt8 = .init(ascii: "E")
    static let R: UInt8 = .init(ascii: "R")
    static let D: UInt8 = .init(ascii: "D")
    static let zero: UInt8 = .init(ascii: "0")
    static let nine: UInt8 = .init(ascii: "9")
    static let increment: UInt8 = .init(ascii: "+")
    static let decrement: UInt8 = .init(ascii: "-")
}
