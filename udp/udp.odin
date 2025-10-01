package godin_udp

import "core:time"
import "core:c"
import "../core"
import "../platform"

// UDP connection implementation for the Godin networking library
// Provides Go-style UDP packet connection functionality

// UDP connection structure
UDP_Connection :: struct {
    socket:     core.Socket,
    local_addr: core.Endpoint,
    closed:     bool,
}

// Listen for UDP packets on the specified address
listen :: proc(network: string, address: string) -> (^UDP_Connection, core.Network_Error) {
    // Parse the endpoint
    endpoint, ok := core.parse_endpoint(address)
    if !ok {
        return nil, core.Address_Error.INVALID_ADDRESS
    }

    // Determine address family
    family: core.Address_Family
    switch network {
    case "udp", "udp4":
        family = .INET
    case "udp6":
        family = .INET6
    case:
        return nil, core.Protocol_Error.INVALID_PROTOCOL
    }

    // Create socket
    sock, err := platform.create_socket(family, .DGRAM, platform.IPPROTO_UDP)
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
    } else when ODIN_OS == .Windows {
        if platform.bind(platform.SOCKET(sock), addr_ptr, c.int(addr_len)) != 0 {
            platform.close_socket(sock)
            return nil, core.Address_Error.ADDRESS_IN_USE
        }
    }

    // Create connection object
    conn := new(UDP_Connection)
    conn.socket = sock
    conn.local_addr = endpoint
    conn.closed = false

    return conn, nil
}

// Dial creates a UDP connection to the specified address (for connected UDP)
dial :: proc(network: string, address: string) -> (^UDP_Connection, core.Network_Error) {
    // Parse the endpoint
    endpoint, ok := core.parse_endpoint(address)
    if !ok {
        return nil, core.Address_Error.INVALID_ADDRESS
    }

    // Determine address family
    family: core.Address_Family
    switch network {
    case "udp", "udp4":
        if !core.is_ipv4(endpoint.address) {
            return nil, core.Address_Error.INVALID_ADDRESS
        }
        family = .INET
    case "udp6":
        if !core.is_ipv6(endpoint.address) {
            return nil, core.Address_Error.INVALID_ADDRESS
        }
        family = .INET6
    case:
        return nil, core.Protocol_Error.INVALID_PROTOCOL
    }

    // Create socket
    sock, err := platform.create_socket(family, .DGRAM, platform.IPPROTO_UDP)
    if err != nil {
        return nil, err
    }

    // Connect to the endpoint (for connected UDP socket)
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
    conn := new(UDP_Connection)
    conn.socket = sock
    // TODO: Get actual local address from socket
    conn.local_addr = core.make_endpoint(core.IPv4_ANY, 0)
    conn.closed = false

    return conn, nil
}

// Packet connection methods implementing the core.Packet_Connection interface

// Read a packet from the UDP connection
udp_read_from :: proc(conn: ^UDP_Connection, buffer: []u8) -> (int, core.Endpoint, core.Network_Error) {
    if conn.closed {
        return 0, {}, core.Connection_Error.CONNECTION_CLOSED
    }

    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        // Storage for source address
        src_addr: platform.sockaddr_in6  // Use IPv6 struct as it's larger
        src_len := c.uint(size_of(platform.sockaddr_in6))

        bytes_read := platform.recvfrom(c.int(conn.socket), raw_data(buffer), len(buffer), 0, &src_addr, &src_len)
        if bytes_read < 0 {
            return 0, {}, core.IO_Error.READ_ERROR
        }

        // Convert sockaddr back to endpoint
        endpoint := sockaddr_to_endpoint(&src_addr, int(src_len))
        return int(bytes_read), endpoint, nil

    } else when ODIN_OS == .Windows {
        // Storage for source address
        src_addr: platform.sockaddr_in6  // Use IPv6 struct as it's larger
        src_len := c.int(size_of(platform.sockaddr_in6))

        bytes_read := platform.recvfrom(platform.SOCKET(conn.socket), raw_data(buffer), c.int(len(buffer)), 0, &src_addr, &src_len)
        if bytes_read < 0 {
            return 0, {}, core.IO_Error.READ_ERROR
        }

        // Convert sockaddr back to endpoint
        endpoint := sockaddr_to_endpoint(&src_addr, int(src_len))
        return int(bytes_read), endpoint, nil
    }
}

// Write a packet to a specific address
udp_write_to :: proc(conn: ^UDP_Connection, data: []u8, addr: core.Endpoint) -> (int, core.Network_Error) {
    if conn.closed {
        return 0, core.Connection_Error.CONNECTION_CLOSED
    }

    addr_ptr, addr_len := platform.ip_to_sockaddr(addr)
    defer free(addr_ptr)

    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        bytes_written := platform.sendto(c.int(conn.socket), raw_data(data), len(data), 0, addr_ptr, addr_len)
        if bytes_written < 0 {
            return 0, core.IO_Error.WRITE_ERROR
        }
        return int(bytes_written), nil

    } else when ODIN_OS == .Windows {
        bytes_written := platform.sendto(platform.SOCKET(conn.socket), raw_data(data), c.int(len(data)), 0, addr_ptr, c.int(addr_len))
        if bytes_written < 0 {
            return 0, core.IO_Error.WRITE_ERROR
        }
        return int(bytes_written), nil
    }
}

// Close the UDP connection
udp_close :: proc(conn: ^UDP_Connection) -> core.Network_Error {
    if conn.closed {
        return nil
    }

    conn.closed = true
    return platform.close_socket(conn.socket)
}

// Get local address
udp_local_addr :: proc(conn: ^UDP_Connection) -> core.Endpoint {
    return conn.local_addr
}

// Set read deadline (simplified implementation)
udp_set_read_deadline :: proc(conn: ^UDP_Connection, deadline: time.Time) -> core.Network_Error {
    // TODO: Implement proper deadline support
    return nil
}

// Set write deadline (simplified implementation)
udp_set_write_deadline :: proc(conn: ^UDP_Connection, deadline: time.Time) -> core.Network_Error {
    // TODO: Implement proper deadline support
    return nil
}

// Set deadline for both read and write
udp_set_deadline :: proc(conn: ^UDP_Connection, deadline: time.Time) -> core.Network_Error {
    if err := udp_set_read_deadline(conn, deadline); err != nil {
        return err
    }
    return udp_set_write_deadline(conn, deadline)
}

// Helper procedures

// Convert platform sockaddr back to core.Endpoint
sockaddr_to_endpoint :: proc(addr: rawptr, len: int) -> core.Endpoint {
    family := (cast(^platform.sockaddr)addr).sa_family

    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        switch family {
        case platform.AF_INET:
            addr_in := cast(^platform.sockaddr_in)addr
            ip := core.IPv4_Address{
                u8(addr_in.sin_addr.s_addr & 0xFF),
                u8((addr_in.sin_addr.s_addr >> 8) & 0xFF),
                u8((addr_in.sin_addr.s_addr >> 16) & 0xFF),
                u8((addr_in.sin_addr.s_addr >> 24) & 0xFF),
            }
            port := platform.swap_bytes(u16(addr_in.sin_port))
            return core.make_endpoint(ip, port)

        case platform.AF_INET6:
            addr_in6 := cast(^platform.sockaddr_in6)addr
            ip := core.IPv6_Address(addr_in6.sin6_addr.s6_addr)
            port := platform.swap_bytes(u16(addr_in6.sin6_port))
            return core.make_endpoint(ip, port)
        }

    } else when ODIN_OS == .Windows {
        switch family {
        case platform.AF_INET:
            addr_in := cast(^platform.sockaddr_in)addr
            ip := core.IPv4_Address{
                u8(addr_in.sin_addr.s_addr & 0xFF),
                u8((addr_in.sin_addr.s_addr >> 8) & 0xFF),
                u8((addr_in.sin_addr.s_addr >> 16) & 0xFF),
                u8((addr_in.sin_addr.s_addr >> 24) & 0xFF),
            }
            port := platform.swap_bytes(u16(addr_in.sin_port))
            return core.make_endpoint(ip, port)

        case platform.AF_INET6:
            addr_in6 := cast(^platform.sockaddr_in6)addr
            ip := core.IPv6_Address(addr_in6.sin6_addr.s6_addr)
            port := platform.swap_bytes(u16(addr_in6.sin6_port))
            return core.make_endpoint(ip, port)
        }
    }

    // Default fallback
    return core.make_endpoint(core.IPv4_ANY, 0)
}

// Convenience procedures

// Close UDP connection (convenience wrapper)
close :: proc(conn: ^UDP_Connection) -> core.Network_Error {
    return udp_close(conn)
}

// Read from UDP connection (convenience wrapper)
read_from :: proc(conn: ^UDP_Connection, buffer: []u8) -> (int, core.Endpoint, core.Network_Error) {
    return udp_read_from(conn, buffer)
}

// Write to UDP connection (convenience wrapper)
write_to :: proc(conn: ^UDP_Connection, data: []u8, addr: core.Endpoint) -> (int, core.Network_Error) {
    return udp_write_to(conn, data, addr)
}