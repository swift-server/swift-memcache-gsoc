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

/// An error thrown as a result of interaction with memcache
public struct MemcacheError: Error, @unchecked Sendable {
    // Note: @unchecked because we use a backing class for storage.

    private var storage: Storage
    private mutating func ensureStorageIsUnique() {
        if !isKnownUniquelyReferenced(&self.storage) {
            self.storage = self.storage.copy()
        }
    }

    private final class Storage {
        var code: Code
        var message: String
        var cause: Error?
        var location: SourceLocation

        init(code: Code, message: String, cause: Error?, location: SourceLocation) {
            self.code = code
            self.message = message
            self.cause = cause
            self.location = location
        }

        func copy() -> Self {
            Self(
                code: self.code,
                message: self.message,
                cause: self.cause,
                location: self.location
            )
        }
    }

    /// A high-level error code to provide a broad classification.
    public var code: Code {
        get { self.storage.code }
        set {
            self.ensureStorageIsUnique()
            self.storage.code = newValue
        }
    }

    /// A message describing what went wrong and how it may be remedied.
    public var message: String {
        get { self.storage.message }
        set {
            self.ensureStorageIsUnique()
            self.storage.message = newValue
        }
    }

    /// An underlying error which caused the operation to fail. This may include additional details
    /// about the root cause of the failure.
    public var cause: Error? {
        get { self.storage.cause }
        set {
            self.ensureStorageIsUnique()
            self.storage.cause = newValue
        }
    }

    /// The location from which this error was thrown.
    public var location: SourceLocation {
        get { self.storage.location }
        set {
            self.ensureStorageIsUnique()
            self.storage.location = newValue
        }
    }

    public init(
        code: Code,
        message: String,
        cause: Error?,
        location: SourceLocation
    ) {
        self.storage = Storage(code: code, message: message, cause: cause, location: location)
    }

    /// Creates a ``MemcacheError`` by wrapping the given `cause` and its location and code.
    internal init(message: String, wrapping cause: MemcacheError) {
        self.init(code: cause.code, message: message, cause: cause, location: cause.location)
    }
}

extension MemcacheError: CustomStringConvertible {
    public var description: String {
        if let cause = self.cause {
            return "\(self.code): \(self.message) (\(cause))"
        } else {
            return "\(self.code): \(self.message)"
        }
    }
}

extension MemcacheError: CustomDebugStringConvertible {
    public var debugDescription: String {
        if let cause = self.cause {
            return
                "\(String(reflecting: self.code)): \(String(reflecting: self.message)) (\(String(reflecting: cause)))"
        } else {
            return "\(String(reflecting: self.code)): \(String(reflecting: self.message))"
        }
    }
}

extension MemcacheError {
    private func detailedDescriptionLines() -> [String] {
        // Build up a tree-like description of the error. This allows nested causes to be formatted
        // correctly, especially when they are also MemcacheError.
        var lines = [
            "MemcacheError: \(self.code)",
            "├─ Reason: \(self.message)",
        ]

        if let error = self.cause as? MemcacheError {
            lines.append("├─ Cause:")
            let causeLines = error.detailedDescriptionLines()
            // We know this will never be empty.
            lines.append("│  └─ \(causeLines.first!)")
            lines.append(contentsOf: causeLines.dropFirst().map { "│     \($0)" })
        } else if let error = self.cause {
            lines.append("├─ Cause: \(String(reflecting: error))")
        }

        lines.append("└─ Source location: \(self.location.function) (\(self.location.file):\(self.location.line))")

        return lines
    }

    /// A detailed multi-line description of the error.
    ///
    /// - Returns: A multi-line description of the error.
    public func detailedDescription() -> String {
        self.detailedDescriptionLines().joined(separator: "\n")
    }
}

extension MemcacheError {
    /// A high level indication of the kind of error being thrown.
    public struct Code: Hashable, Sendable, CustomStringConvertible {
        private enum Wrapped: Hashable, Sendable, CustomStringConvertible {
            /// Indicates that the connection has shut down.
            case connectionShutdown
            /// Indicates that there was a violation or inconsistency in the expected Memcache protocol behavior.
            case protocolError
            /// Indicates that the key was not found.
            case keyNotFound
            /// Indicates that the key already exist
            case keyExist

            var description: String {
                switch self {
                case .connectionShutdown:
                    return "Connection shutdown"
                case .protocolError:
                    return "Protocol Error"
                case .keyNotFound:
                    return "Key not Found"
                case .keyExist:
                    return "Key already Exist"
                }
            }
        }

        public var description: String {
            String(describing: self.code)
        }

        private var code: Wrapped
        private init(_ code: Wrapped) {
            self.code = code
        }

        /// The ``MemcacheConnection`` is already shutdown.
        public static var connectionShutdown: Self {
            Self(.connectionShutdown)
        }

        /// Indicates that a nil response was received from the server.
        public static var protocolError: Self {
            Self(.protocolError)
        }

        /// Indicates that the key was not found.
        public static var keyNotFound: Self {
            Self(.keyNotFound)
        }

        /// Indicates that the key already exists.
        public static var keyExist: Self {
            Self(.keyExist)
        }
    }

    /// A location within source code.
    public struct SourceLocation: Sendable, Hashable {
        /// The function in which the error was thrown.
        public var function: String

        /// The file in which the error was thrown.
        public var file: String

        /// The line on which the error was thrown.
        public var line: Int

        public init(function: String, file: String, line: Int) {
            self.function = function
            self.file = file
            self.line = line
        }

        internal static func here(
            function: String = #function,
            file: String = #fileID,
            line: Int = #line
        ) -> Self {
            SourceLocation(function: function, file: file, line: line)
        }
    }
}
