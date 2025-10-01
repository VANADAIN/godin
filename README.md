# Godin - Go-style Net Package for Odin

Godin is a comprehensive networking library for the Odin programming language that provides Go's net package functionality and API design patterns, leveraging Odin's unique language features for improved type safety and performance.

## Features

- **Core Networking**: TCP, UDP, and Unix domain socket support
- **HTTP Client/Server**: Full HTTP/1.1 implementation with client and server support
- **DNS Resolution**: Comprehensive DNS client with caching
- **TLS/SSL**: Secure transport layer implementation
- **URL Parsing**: Complete URL manipulation utilities
- **Connection Pooling**: Efficient connection management
- **Cross-Platform**: Support for Linux, Windows, macOS, and FreeBSD
- **Type Safety**: Leverages Odin's union types and distinct types for better error handling

## Quick Start

```odin
package main

import "godin/core"
import "godin/tcp"
import "godin/http"

main :: proc() {
    // TCP client example
    conn, err := tcp.dial("tcp", "example.com:80")
    if err != nil {
        fmt.println("Connection failed:", err)
        return
    }
    defer tcp.close(conn)

    // HTTP client example
    response, err := http.get("https://api.github.com/users/octocat")
    if err != nil {
        fmt.println("HTTP request failed:", err)
        return
    }
    defer http.close_response(response)

    fmt.println("Status:", response.status_code)
}
```

## Package Structure

- `core/` - Core types, interfaces, and common networking primitives
- `tcp/` - TCP connection implementation
- `udp/` - UDP connection implementation
- `dns/` - DNS resolution and caching
- `http/` - HTTP client and server implementation
- `tls/` - TLS/SSL secure transport
- `url/` - URL parsing and manipulation
- `platform/` - Platform-specific socket implementations
- `utils/` - Utilities like connection pooling and timeout management
- `examples/` - Example usage and demos

## Design Philosophy

Godin aims to provide:

1. **Go Compatibility**: API design that closely mirrors Go's net package
2. **Odin Advantages**: Leverages Odin's language features for better type safety
3. **Performance**: Zero-cost abstractions and efficient memory management
4. **Simplicity**: Clean, readable API that's easy to use and understand
5. **Completeness**: Full-featured networking stack suitable for production use

## Installation

```bash
# Clone the repository
git clone https://github.com/your-username/godin.git

# Add to your Odin project
# Import the modules you need in your .odin files
```

## Contributing

Contributions are welcome! Please feel free to submit pull requests, report bugs, or suggest new features.

## License

MIT License - see LICENSE file for details.