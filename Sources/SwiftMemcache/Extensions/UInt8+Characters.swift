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
}
