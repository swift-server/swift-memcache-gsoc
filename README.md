# 🚧WIP🚧: SwiftMemcache

SwiftMemcache is a Swift Package in development that provides a convenient way to communicate with [Memcached](https://github.com/memcached/memcached) servers.

## Getting Started

## Overview

### Memcache Connection API

Our `MemcacheConnection` allows for communicate with a Memcached server. This actor takes care of establishing a connection, creating a request stream and handling asynchronous execution of commands.

Here's an example of how you can use `MemcachedConnection` in a program.

```swift
@main
struct Program {
    // Use the shared singleton instance of MultiThreadedEventLoopGroup
    static let eventLoopGroup = MultiThreadedEventLoopGroup.singleton
    // Initialize the logger
    static let logger = Logger(label: "memcache")

    static func main() async throws {
        // Instantiate a new MemcacheConnection actor with host, port, and event loop group
        let memcacheConnection = MemcacheConnection(host: "127.0.0.1", port: 11211, eventLoopGroup: eventLoopGroup)

        // Initialize the service group
        let serviceGroup = ServiceGroup(services: [memcacheConnection], logger: self.logger)

        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add the connection actor's run function to the task group
            // This opens the connection and handles requests until the task is cancelled or the connection is closed
            group.addTask { try await serviceGroup.run() }

            // Set a value for a key.
            let setValue = "bar"
            try await memcacheConnection.set("foo", value: setValue)

            // Get the value for a key.
            // Specify the expected type for the value returned from Memcache.
            let getValue: String? = try await memcacheConnection.get("foo")

            // Assert that the get operation was successful by comparing the value set and the value returned from Memcache.
            // If they are not equal, this will throw an error.
            assert(getValue == setValue, "Value retrieved from Memcache does not match the set value")

            // Cancel all tasks in the task group.
            // This also results in the connection to Memcache being closed.
            group.cancelAll()
        }
    }
}
```

## Contributing

### Docker

We provide a Docker environment for this package. This will automatically start a local Memcached server and run the package tests.

```bash
docker-compose -f docker/docker-compose.yaml run test
```
