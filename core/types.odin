package godin_core

import "core:time"
import "core:strings"
import "core:strconv"
import "core:fmt"

// Core networking types and interfaces for the Godin networking library
// This module provides the fundamental abstractions used throughout the package

// Network error types using Odin's union for comprehensive error handling
Network_Error :: union {
    Connection_Error,
    Timeout_Error,
    DNS_Error,
    Address_Error,
    Protocol_Error,
    IO_Error,
    System_Error,
}

Connection_Error :: enum {
    CONNECTION_REFUSED,
    CONNECTION_RESET,
    CONNECTION_ABORTED,
    CONNECTION_CLOSED,
    CONNECTION_TIMEOUT,
    NETWORK_UNREACHABLE,
    HOST_UNREACHABLE,
    NO_ROUTE_TO_HOST,
}

Timeout_Error :: enum {
    READ_TIMEOUT,
    WRITE_TIMEOUT,
    CONNECT_TIMEOUT,
    DEADLINE_EXCEEDED,
}

DNS_Error :: enum {
    NAME_NOT_FOUND,
    SERVER_FAILURE,
    NO_DATA,
    INVALID_NAME,
    DNS_TIMEOUT,
}

Address_Error :: enum {
    INVALID_ADDRESS,
    INVALID_PORT,
    ADDRESS_IN_USE,
    ADDRESS_NOT_AVAILABLE,
}

Protocol_Error :: enum {
    INVALID_PROTOCOL,
    PROTOCOL_NOT_SUPPORTED,
    OPERATION_NOT_SUPPORTED,
}

IO_Error :: enum {
    READ_ERROR,
    WRITE_ERROR,
    BUFFER_TOO_SMALL,
    UNEXPECTED_EOF,
}

System_Error :: enum {
    OUT_OF_MEMORY,
    PERMISSION_DENIED,
    RESOURCE_UNAVAILABLE,
    SYSTEM_ERROR,
}

// Socket represents a network socket handle
Socket :: distinct int

// Network represents the type of network connection
Network :: enum {
    TCP,
    TCP4,
    TCP6,
    UDP,
    UDP4,
    UDP6,
    UNIX,
    UNIXGRAM,
    UNIXPACKET,
}

// Protocol family constants
Address_Family :: enum {
    UNSPEC = 0,
    INET   = 2,  // IPv4
    INET6  = 10, // IPv6
    UNIX   = 1,  // Unix domain sockets
}

// Socket types
Socket_Type :: enum {
    STREAM    = 1, // TCP
    DGRAM     = 2, // UDP
    RAW       = 3, // Raw sockets
    SEQPACKET = 5, // Sequenced packet socket
}

// IP address representation using union for type safety
IP_Address :: union {
    IPv4_Address,
    IPv6_Address,
}

// IPv4 address - 4 bytes
IPv4_Address :: distinct [4]u8

// IPv6 address - 16 bytes
IPv6_Address :: distinct [16]u8

// Network endpoint combining address and port
Endpoint :: struct {
    address: IP_Address,
    port:    u16,
}

// TCP endpoint specifically for TCP connections
TCP_Endpoint :: struct {
    address: IP_Address,
    port:    u16,
}

// UDP endpoint specifically for UDP connections
UDP_Endpoint :: struct {
    address: IP_Address,
    port:    u16,
}

// Forward declarations for connection types
// These will be implemented by concrete types in TCP/UDP modules

// Dial configuration options
Dial_Config :: struct {
    timeout:     time.Duration,
    local_addr:  ^Endpoint,
    keep_alive:  bool,
    keep_alive_period: time.Duration,
}

// Listen configuration options
Listen_Config :: struct {
    backlog:     int,
    reuse_addr:  bool,
    reuse_port:  bool,
}

// Socket options
Socket_Option :: union {
    Socket_Option_Bool,
    Socket_Option_Int,
    Socket_Option_Duration,
}

Socket_Option_Bool :: struct {
    level:  int,
    option: int,
    value:  bool,
}

Socket_Option_Int :: struct {
    level:  int,
    option: int,
    value:  int,
}

Socket_Option_Duration :: struct {
    level:  int,
    option: int,
    value:  time.Duration,
}

// Standard socket option constants
SO_REUSEADDR  :: 2
SO_KEEPALIVE  :: 9
SO_BROADCAST  :: 6
SO_LINGER     :: 13
SO_RCVTIMEO   :: 20
SO_SNDTIMEO   :: 21
SO_RCVBUF     :: 8
SO_SNDBUF     :: 7

// IP protocol levels
SOL_SOCKET    :: 1
IPPROTO_TCP   :: 6
IPPROTO_UDP   :: 17
IPPROTO_IP    :: 0
IPPROTO_IPV6  :: 41

// Common IP addresses
IPv4_LOOPBACK   :: IPv4_Address{127, 0, 0, 1}
IPv4_BROADCAST  :: IPv4_Address{255, 255, 255, 255}
IPv4_ANY        :: IPv4_Address{0, 0, 0, 0}

IPv6_LOOPBACK   :: IPv6_Address{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1}
IPv6_ANY        :: IPv6_Address{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

// Utility procedures

// Convert string to IP address
parse_ip :: proc(s: string) -> (IP_Address, bool) {
    // Try IPv4 first
    if ipv4, ok := parse_ipv4(s); ok {
        return ipv4, true
    }

    // Try IPv6
    if ipv6, ok := parse_ipv6(s); ok {
        return ipv6, true
    }

    return nil, false
}

// Convert IP address to string
ip_to_string :: proc(ip: IP_Address) -> string {
    switch addr in ip {
    case IPv4_Address:
        return ipv4_to_string(addr)
    case IPv6_Address:
        return ipv6_to_string(addr)
    }
    return ""
}

// Check if IP is IPv4
is_ipv4 :: proc(ip: IP_Address) -> bool {
    _, ok := ip.(IPv4_Address)
    return ok
}

// Check if IP is IPv6
is_ipv6 :: proc(ip: IP_Address) -> bool {
    _, ok := ip.(IPv6_Address)
    return ok
}

// Get the address family for an IP address
get_address_family :: proc(ip: IP_Address) -> Address_Family {
    switch addr in ip {
    case IPv4_Address:
        return .INET
    case IPv6_Address:
        return .INET6
    }
    return .UNSPEC
}

// Helper procedures for IP address parsing and conversion

// Parse IPv4 address from string (e.g., "192.168.1.1")
parse_ipv4 :: proc(s: string) -> (IPv4_Address, bool) {
    parts := strings.split(s, ".")
    defer delete(parts)

    if len(parts) != 4 {
        return {}, false
    }

    addr: IPv4_Address
    for part, i in parts {
        val, ok := strconv.parse_int(part, 10)
        if !ok || val < 0 || val > 255 {
            return {}, false
        }
        addr[i] = u8(val)
    }

    return addr, true
}

// Parse IPv6 address from string (simplified version - supports standard notation)
parse_ipv6 :: proc(s: string) -> (IPv6_Address, bool) {
    // Handle loopback shorthand
    if s == "::1" {
        return IPv6_LOOPBACK, true
    }

    // Handle any address shorthand
    if s == "::" {
        return IPv6_ANY, true
    }

    // For now, implement basic parsing - a full IPv6 parser would be more complex
    if strings.contains(s, "::") {
        // Handle compressed notation
        parts := strings.split(s, "::")
        defer delete(parts)

        if len(parts) > 2 {
            return {}, false
        }

        // This is a simplified implementation
        // A complete implementation would handle all IPv6 notation forms
        return {}, false
    }

    // Handle full notation
    parts := strings.split(s, ":")
    defer delete(parts)

    if len(parts) != 8 {
        return {}, false
    }

    addr: IPv6_Address
    for part, i in parts {
        if len(part) == 0 || len(part) > 4 {
            return {}, false
        }

        val, ok := strconv.parse_int(part, 16)
        if !ok || val < 0 || val > 0xFFFF {
            return {}, false
        }

        // Store as big-endian
        addr[i*2] = u8(val >> 8)
        addr[i*2 + 1] = u8(val & 0xFF)
    }

    return addr, true
}

// Convert IPv4 address to string
ipv4_to_string :: proc(addr: IPv4_Address) -> string {
    return fmt.aprintf("%d.%d.%d.%d", addr[0], addr[1], addr[2], addr[3])
}

// Convert IPv6 address to string
ipv6_to_string :: proc(addr: IPv6_Address) -> string {
    // Check for special addresses
    if addr == IPv6_LOOPBACK {
        return "::1"
    }
    if addr == IPv6_ANY {
        return "::"
    }

    // Convert to colon-separated hex notation
    parts: [8]string
    for i in 0..<8 {
        val := (u16(addr[i*2]) << 8) | u16(addr[i*2 + 1])
        parts[i] = fmt.aprintf("%x", val)
    }

    return strings.join(parts[:], ":")
}

// Create an endpoint from address and port
make_endpoint :: proc(address: IP_Address, port: u16) -> Endpoint {
    return Endpoint{address = address, port = port}
}

// Create a TCP endpoint
make_tcp_endpoint :: proc(address: IP_Address, port: u16) -> TCP_Endpoint {
    return TCP_Endpoint{address = address, port = port}
}

// Create a UDP endpoint
make_udp_endpoint :: proc(address: IP_Address, port: u16) -> UDP_Endpoint {
    return UDP_Endpoint{address = address, port = port}
}

// Convert endpoint to string
endpoint_to_string :: proc(ep: Endpoint) -> string {
    addr_str := ip_to_string(ep.address)
    if is_ipv6(ep.address) {
        return fmt.aprintf("[%s]:%d", addr_str, ep.port)
    }
    return fmt.aprintf("%s:%d", addr_str, ep.port)
}

// Parse network address string "host:port"
parse_endpoint :: proc(s: string) -> (Endpoint, bool) {
    // Handle IPv6 addresses with brackets [::1]:8080
    if strings.has_prefix(s, "[") {
        close_bracket := strings.index(s, "]")
        if close_bracket == -1 {
            return {}, false
        }

        addr_str := s[1:close_bracket]
        remainder := s[close_bracket+1:]

        if !strings.has_prefix(remainder, ":") {
            return {}, false
        }

        port_str := remainder[1:]
        port, port_ok := strconv.parse_int(port_str, 10)
        if !port_ok || port < 0 || port > 65535 {
            return {}, false
        }

        addr, addr_ok := parse_ip(addr_str)
        if !addr_ok {
            return {}, false
        }

        return Endpoint{address = addr, port = u16(port)}, true
    }

    // Handle IPv4 or hostname
    last_colon := strings.last_index(s, ":")
    if last_colon == -1 {
        return {}, false
    }

    addr_str := s[:last_colon]
    port_str := s[last_colon+1:]

    port, port_ok := strconv.parse_int(port_str, 10)
    if !port_ok || port < 0 || port > 65535 {
        return {}, false
    }

    addr, addr_ok := parse_ip(addr_str)
    if !addr_ok {
        return {}, false
    }

    return Endpoint{address = addr, port = u16(port)}, true
}