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

typealias ResponseStatus = UInt16

extension ResponseStatus {
    // generates a 16-bit code from two ASCII characters
    static func generateCode(from characters: (UInt8, UInt8)) -> ResponseStatus {
        return ResponseStatus(characters.0) << 8 | ResponseStatus(characters.1)
    }

    static let stored = generateCode(from: (.init(ascii: "H"), .init(ascii: "D")))
    static let notStored = generateCode(from: (.init(ascii: "N"), .init(ascii: "S")))
    static let exists = generateCode(from: (.init(ascii: "E"), .init(ascii: "X")))
    static let notFound = generateCode(from: (.init(ascii: "N"), .init(ascii: "F")))

    init?(asciiValues: (UInt8, UInt8)) {
        let code = ResponseStatus(asciiValues.0) << 8 | ResponseStatus(asciiValues.1)

        switch code {
        case ResponseStatus.stored, ResponseStatus.notStored, ResponseStatus.exists, ResponseStatus.notFound:
            self = code
        default:
            preconditionFailure("Unrecognized response code.")
        }
    }
}
