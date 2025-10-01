package godin_tcp

import "core:time"
import "core:c"
import "../core"
import "../platform"

// TCP connection implementation for the Godin networking library
// Provides Go-style TCP connection functionality with Odin type safety

// TCP connection structure
TCP_Connection :: struct {
    socket:      core.Socket,
    local_addr:  core.Endpoint,
    remote_addr: core.Endpoint,
    closed:      bool,
}

// TCP listener structure
TCP_Listener :: struct {
    socket:     core.Socket,
    local_addr: core.Endpoint,
    closed:     bool,
}

// Dial creates a TCP connection to the specified address
dial :: proc(network: string, address: string) -> (^TCP_Connection, core.Network_Error) {
    return dial_timeout(network, address, 0)
}

// Dial with timeout
dial_timeout :: proc(network: string, address: string, timeout: time.Duration) -> (^TCP_Connection, core.Network_Error) {
    // Parse the endpoint
    endpoint, ok := core.parse_endpoint(address)
    if !ok {
        return nil, core.Address_Error.INVALID_ADDRESS
    }

    // Determine address family
    family: core.Address_Family
    switch network {
    case "tcp", "tcp4":
        if !core.is_ipv4(endpoint.address) {
            return nil, core.Address_Error.INVALID_ADDRESS
        }
        family = .INET
    case "tcp6":
        if !core.is_ipv6(endpoint.address) {
            return nil, core.Address_Error.INVALID_ADDRESS
        }
        family = .INET6
    case:
        return nil, core.Protocol_Error.INVALID_PROTOCOL
    }

    // Create socket
    sock, err := platform.create_socket(family, .STREAM, platform.IPPROTO_TCP)
    if err != nil {
        return nil, err
    }

    // Connect to the endpoint
    addr_ptr, addr_len := platform.ip_to_sockaddr(endpoint)
    defer free(addr_ptr)

    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        result := platform.connect(c.int(sock), addr_ptr, addr_len)
        if result < 0 {
            platform.close_socket(sock)
            return nil, core.Connection_Error.CONNECTION_REFUSED
        }
    } else when ODIN_OS == .Windows {
        result := platform.connect(platform.SOCKET(sock), addr_ptr, c.int(addr_len))
        if result != 0 {
            platform.close_socket(sock)
            return nil, core.Connection_Error.CONNECTION_REFUSED
        }
    }

    // Create connection object
    conn := new(TCP_Connection)
    conn.socket = sock
    conn.remote_addr = endpoint
    // TODO: Get actual local address from socket
    conn.local_addr = core.make_endpoint(core.IPv4_ANY, 0)
    conn.closed = false

    return conn, nil
}

// Listen creates a TCP listener on the specified address
listen :: proc(network: string, address: string) -> (^TCP_Listener, core.Network_Error) {
    // Parse the endpoint
    endpoint, ok := core.parse_endpoint(address)
    if !ok {
        return nil, core.Address_Error.INVALID_ADDRESS
    }

    // Determine address family
    family: core.Address_Family
    switch network {
    case "tcp", "tcp4":
        family = .INET
    case "tcp6":
        family = .INET6
    case:
        return nil, core.Protocol_Error.INVALID_PROTOCOL
    }

    // Create socket
    sock, err := platform.create_socket(family, .STREAM, platform.IPPROTO_TCP)
    if err != nil {
        return nil, err
    }

    // Set SO_REUSEADDR
    reuse_val := c.int(1)
    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        platform.setsockopt(c.int(sock), platform.SOL_SOCKET, platform.SO_REUSEADDR, &reuse_val, size_of(c.int))
    } else when ODIN_OS == .Windows {
        platform.setsockopt(platform.SOCKET(sock), platform.SOL_SOCKET, platform.SO_REUSEADDR, &reuse_val, size_of(c.int))
    }

    // Bind to the endpoint
    addr_ptr, addr_len := platform.ip_to_sockaddr(endpoint)
    defer free(addr_ptr)

    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        if platform.bind(c.int(sock), addr_ptr, addr_len) < 0 {
            platform.close_socket(sock)
            return nil, core.Address_Error.ADDRESS_IN_USE
        }

        // Start listening
        if platform.listen(c.int(sock), 128) < 0 {  // Backlog of 128
            platform.close_socket(sock)
            return nil, core.System_Error.SYSTEM_ERROR
        }

    } else when ODIN_OS == .Windows {
        if platform.bind(platform.SOCKET(sock), addr_ptr, c.int(addr_len)) != 0 {
            platform.close_socket(sock)
            return nil, core.Address_Error.ADDRESS_IN_USE
        }

        // Start listening
        if platform.listen(platform.SOCKET(sock), 128) != 0 {  // Backlog of 128
            platform.close_socket(sock)
            return nil, core.System_Error.SYSTEM_ERROR
        }
    }

    // Create listener object
    listener := new(TCP_Listener)
    listener.socket = sock
    listener.local_addr = endpoint
    listener.closed = false

    return listener, nil
}

// Connection methods implementing the core.Connection interface

// Read data from the TCP connection
tcp_read :: proc(conn: ^TCP_Connection, buffer: []u8) -> (int, core.Network_Error) {
    if conn.closed {
        return 0, core.Connection_Error.CONNECTION_CLOSED
    }

    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        bytes_read := platform.recv(c.int(conn.socket), raw_data(buffer), len(buffer), 0)
        if bytes_read < 0 {
            return 0, core.IO_Error.READ_ERROR
        }
        if bytes_read == 0 {
            return 0, core.IO_Error.UNEXPECTED_EOF
        }
        return int(bytes_read), nil

    } else when ODIN_OS == .Windows {
        bytes_read := platform.recv(platform.SOCKET(conn.socket), raw_data(buffer), c.int(len(buffer)), 0)
        if bytes_read < 0 {
            return 0, core.IO_Error.READ_ERROR
        }
        if bytes_read == 0 {
            return 0, core.IO_Error.UNEXPECTED_EOF
        }
        return int(bytes_read), nil
    }
}

// Write data to the TCP connection
tcp_write :: proc(conn: ^TCP_Connection, data: []u8) -> (int, core.Network_Error) {
    if conn.closed {
        return 0, core.Connection_Error.CONNECTION_CLOSED
    }

    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        bytes_written := platform.send(c.int(conn.socket), raw_data(data), len(data), 0)
        if bytes_written < 0 {
            return 0, core.IO_Error.WRITE_ERROR
        }
        return int(bytes_written), nil

    } else when ODIN_OS == .Windows {
        bytes_written := platform.send(platform.SOCKET(conn.socket), raw_data(data), c.int(len(data)), 0)
        if bytes_written < 0 {
            return 0, core.IO_Error.WRITE_ERROR
        }
        return int(bytes_written), nil
    }
}

// Close the TCP connection
tcp_close :: proc(conn: ^TCP_Connection) -> core.Network_Error {
    if conn.closed {
        return nil
    }

    conn.closed = true
    return platform.close_socket(conn.socket)
}

// Get local endpoint
tcp_local_addr :: proc(conn: ^TCP_Connection) -> core.Endpoint {
    return conn.local_addr
}

// Get remote endpoint
tcp_remote_addr :: proc(conn: ^TCP_Connection) -> core.Endpoint {
    return conn.remote_addr
}

// Set read deadline (simplified implementation)
tcp_set_read_deadline :: proc(conn: ^TCP_Connection, deadline: time.Time) -> core.Network_Error {
    // TODO: Implement proper deadline support
    return nil
}

// Set write deadline (simplified implementation)
tcp_set_write_deadline :: proc(conn: ^TCP_Connection, deadline: time.Time) -> core.Network_Error {
    // TODO: Implement proper deadline support
    return nil
}

// Set deadline for both read and write
tcp_set_deadline :: proc(conn: ^TCP_Connection, deadline: time.Time) -> core.Network_Error {
    if err := tcp_set_read_deadline(conn, deadline); err != nil {
        return err
    }
    return tcp_set_write_deadline(conn, deadline)
}

// Listener methods implementing the core.Listener interface

// Accept an incoming connection
tcp_accept :: proc(listener: ^TCP_Listener) -> (^TCP_Connection, core.Network_Error) {
    if listener.closed {
        return nil, core.Connection_Error.CONNECTION_CLOSED
    }

    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        client_sock := platform.accept(c.int(listener.socket), nil, nil)
        if client_sock < 0 {
            return nil, core.Connection_Error.CONNECTION_REFUSED
        }

        // Create connection object
        conn := new(TCP_Connection)
        conn.socket = core.Socket(client_sock)
        // TODO: Get actual addresses from socket
        conn.local_addr = listener.local_addr
        conn.remote_addr = core.make_endpoint(core.IPv4_ANY, 0)
        conn.closed = false

        return conn, nil

    } else when ODIN_OS == .Windows {
        client_sock := platform.accept(platform.SOCKET(listener.socket), nil, nil)
        if client_sock == platform.INVALID_SOCKET {
            return nil, core.Connection_Error.CONNECTION_REFUSED
        }

        // Create connection object
        conn := new(TCP_Connection)
        conn.socket = core.Socket(uintptr(client_sock))
        // TODO: Get actual addresses from socket
        conn.local_addr = listener.local_addr
        conn.remote_addr = core.make_endpoint(core.IPv4_ANY, 0)
        conn.closed = false

        return conn, nil
    }
}

// Close the TCP listener
tcp_listener_close :: proc(listener: ^TCP_Listener) -> core.Network_Error {
    if listener.closed {
        return nil
    }

    listener.closed = true
    return platform.close_socket(listener.socket)
}

// Get the listener's address
tcp_listener_addr :: proc(listener: ^TCP_Listener) -> core.Endpoint {
    return listener.local_addr
}

// Convenience procedures for common operations

// Close any TCP connection (works with interface)
close :: proc(conn: ^TCP_Connection) -> core.Network_Error {
    return tcp_close(conn)
}

// Read from TCP connection (convenience wrapper)
read :: proc(conn: ^TCP_Connection, buffer: []u8) -> (int, core.Network_Error) {
    return tcp_read(conn, buffer)
}

// Write to TCP connection (convenience wrapper)
write :: proc(conn: ^TCP_Connection, data: []u8) -> (int, core.Network_Error) {
    return tcp_write(conn, data)
}