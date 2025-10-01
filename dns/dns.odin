package godin_dns

import "core:c"
import "core:strings"
import "../core"

// DNS resolution for the Godin networking library
// Provides Go-style DNS lookup functionality

// DNS record types
DNS_Record_Type :: enum {
    A     = 1,   // IPv4 address
    AAAA  = 28,  // IPv6 address
    CNAME = 5,   // Canonical name
    MX    = 15,  // Mail exchange
    NS    = 2,   // Name server
    PTR   = 12,  // Pointer
    SOA   = 6,   // Start of authority
    TXT   = 16,  // Text
}

// DNS lookup result
DNS_Result :: struct {
    addresses: []core.IP_Address,
    cnames:    []string,
}

// Platform-specific DNS resolution
when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {

    foreign import libc "system:c"

    // Address info structures for getaddrinfo
    addrinfo :: struct {
        ai_flags:     c.int,
        ai_family:    c.int,
        ai_socktype:  c.int,
        ai_protocol:  c.int,
        ai_addrlen:   c.size_t,
        ai_addr:      ^sockaddr,
        ai_canonname: cstring,
        ai_next:      ^addrinfo,
    }

    sockaddr :: struct {
        sa_family: c.ushort,
        sa_data:   [14]c.char,
    }

    sockaddr_in :: struct {
        sin_family: c.ushort,
        sin_port:   c.ushort,
        sin_addr:   in_addr,
        sin_zero:   [8]c.char,
    }

    sockaddr_in6 :: struct {
        sin6_family:   c.ushort,
        sin6_port:     c.ushort,
        sin6_flowinfo: c.uint,
        sin6_addr:     in6_addr,
        sin6_scope_id: c.uint,
    }

    in_addr :: struct {
        s_addr: c.uint,
    }

    in6_addr :: struct {
        s6_addr: [16]c.uchar,
    }

    foreign libc {
        getaddrinfo  :: proc(node: cstring, service: cstring, hints: ^addrinfo, res: ^^addrinfo) -> c.int ---
        freeaddrinfo :: proc(res: ^addrinfo) ---
        gai_strerror :: proc(errcode: c.int) -> cstring ---
    }

    // Constants
    AF_INET  :: 2
    AF_INET6 :: 10
    AF_UNSPEC :: 0

    SOCK_STREAM :: 1
    SOCK_DGRAM  :: 2

} else when ODIN_OS == .Windows {

    foreign import ws2_32 "system:ws2_32.lib"

    // Windows uses similar structures
    ADDRINFOA :: struct {
        ai_flags:     c.int,
        ai_family:    c.int,
        ai_socktype:  c.int,
        ai_protocol:  c.int,
        ai_addrlen:   c.size_t,
        ai_canonname: cstring,
        ai_addr:      ^SOCKADDR,
        ai_next:      ^ADDRINFOA,
    }

    SOCKADDR :: struct {
        sa_family: c.ushort,
        sa_data:   [14]c.char,
    }

    SOCKADDR_IN :: struct {
        sin_family: c.short,
        sin_port:   c.ushort,
        sin_addr:   IN_ADDR,
        sin_zero:   [8]c.char,
    }

    SOCKADDR_IN6 :: struct {
        sin6_family:   c.short,
        sin6_port:     c.ushort,
        sin6_flowinfo: c.ulong,
        sin6_addr:     IN6_ADDR,
        sin6_scope_id: c.ulong,
    }

    IN_ADDR :: struct {
        s_addr: c.ulong,
    }

    IN6_ADDR :: struct {
        s6_addr: [16]c.uchar,
    }

    foreign ws2_32 {
        GetAddrInfoA  :: proc(pNodeName: cstring, pServiceName: cstring, pHints: ^ADDRINFOA, ppResult: ^^ADDRINFOA) -> c.int ---
        FreeAddrInfoA :: proc(pAddrInfo: ^ADDRINFOA) ---
    }

    // Constants
    AF_INET   :: 2
    AF_INET6  :: 23
    AF_UNSPEC :: 0

    SOCK_STREAM :: 1
    SOCK_DGRAM  :: 2

} else {
    #panic("Unsupported operating system")
}

// Resolve hostname to IP addresses
lookup_host :: proc(hostname: string) -> (DNS_Result, core.Network_Error) {
    cname := strings.clone_to_cstring(hostname)
    defer delete(cname)

    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        hints := addrinfo{
            ai_family = AF_UNSPEC,  // Allow both IPv4 and IPv6
            ai_socktype = SOCK_STREAM,
        }

        result: ^addrinfo
        err := getaddrinfo(cname, nil, &hints, &result)
        if err != 0 {
            return {}, core.DNS_Error.NAME_NOT_FOUND
        }
        defer freeaddrinfo(result)

        dns_result := DNS_Result{}
        addresses := make([dynamic]core.IP_Address)

        current := result
        for current != nil {
            switch current.ai_family {
            case AF_INET:
                addr_in := cast(^sockaddr_in)current.ai_addr
                ipv4 := core.IPv4_Address{
                    u8(addr_in.sin_addr.s_addr & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 8) & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 16) & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 24) & 0xFF),
                }
                append(&addresses, ipv4)

            case AF_INET6:
                addr_in6 := cast(^sockaddr_in6)current.ai_addr
                ipv6 := core.IPv6_Address(addr_in6.sin6_addr.s6_addr)
                append(&addresses, ipv6)
            }

            current = current.ai_next
        }

        dns_result.addresses = addresses[:]
        return dns_result, nil

    } else when ODIN_OS == .Windows {
        hints := ADDRINFOA{
            ai_family = AF_UNSPEC,  // Allow both IPv4 and IPv6
            ai_socktype = SOCK_STREAM,
        }

        result: ^ADDRINFOA
        err := GetAddrInfoA(cname, nil, &hints, &result)
        if err != 0 {
            return {}, core.DNS_Error.NAME_NOT_FOUND
        }
        defer FreeAddrInfoA(result)

        dns_result := DNS_Result{}
        addresses := make([dynamic]core.IP_Address)

        current := result
        for current != nil {
            switch current.ai_family {
            case AF_INET:
                addr_in := cast(^SOCKADDR_IN)current.ai_addr
                ipv4 := core.IPv4_Address{
                    u8(addr_in.sin_addr.s_addr & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 8) & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 16) & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 24) & 0xFF),
                }
                append(&addresses, ipv4)

            case AF_INET6:
                addr_in6 := cast(^SOCKADDR_IN6)current.ai_addr
                ipv6 := core.IPv6_Address(addr_in6.sin6_addr.s6_addr)
                append(&addresses, ipv6)
            }

            current = current.ai_next
        }

        dns_result.addresses = addresses[:]
        return dns_result, nil
    }
}

// Resolve hostname to IPv4 addresses only
lookup_ipv4 :: proc(hostname: string) -> ([]core.IPv4_Address, core.Network_Error) {
    cname := strings.clone_to_cstring(hostname)
    defer delete(cname)

    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        hints := addrinfo{
            ai_family = AF_INET,  // IPv4 only
            ai_socktype = SOCK_STREAM,
        }

        result: ^addrinfo
        err := getaddrinfo(cname, nil, &hints, &result)
        if err != 0 {
            return nil, core.DNS_Error.NAME_NOT_FOUND
        }
        defer freeaddrinfo(result)

        addresses := make([dynamic]core.IPv4_Address)

        current := result
        for current != nil {
            if current.ai_family == AF_INET {
                addr_in := cast(^sockaddr_in)current.ai_addr
                ipv4 := core.IPv4_Address{
                    u8(addr_in.sin_addr.s_addr & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 8) & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 16) & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 24) & 0xFF),
                }
                append(&addresses, ipv4)
            }

            current = current.ai_next
        }

        return addresses[:], nil

    } else when ODIN_OS == .Windows {
        hints := ADDRINFOA{
            ai_family = AF_INET,  // IPv4 only
            ai_socktype = SOCK_STREAM,
        }

        result: ^ADDRINFOA
        err := GetAddrInfoA(cname, nil, &hints, &result)
        if err != 0 {
            return nil, core.DNS_Error.NAME_NOT_FOUND
        }
        defer FreeAddrInfoA(result)

        addresses := make([dynamic]core.IPv4_Address)

        current := result
        for current != nil {
            if current.ai_family == AF_INET {
                addr_in := cast(^SOCKADDR_IN)current.ai_addr
                ipv4 := core.IPv4_Address{
                    u8(addr_in.sin_addr.s_addr & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 8) & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 16) & 0xFF),
                    u8((addr_in.sin_addr.s_addr >> 24) & 0xFF),
                }
                append(&addresses, ipv4)
            }

            current = current.ai_next
        }

        return addresses[:], nil
    }
}

// Resolve hostname to IPv6 addresses only
lookup_ipv6 :: proc(hostname: string) -> ([]core.IPv6_Address, core.Network_Error) {
    cname := strings.clone_to_cstring(hostname)
    defer delete(cname)

    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        hints := addrinfo{
            ai_family = AF_INET6,  // IPv6 only
            ai_socktype = SOCK_STREAM,
        }

        result: ^addrinfo
        err := getaddrinfo(cname, nil, &hints, &result)
        if err != 0 {
            return nil, core.DNS_Error.NAME_NOT_FOUND
        }
        defer freeaddrinfo(result)

        addresses := make([dynamic]core.IPv6_Address)

        current := result
        for current != nil {
            if current.ai_family == AF_INET6 {
                addr_in6 := cast(^sockaddr_in6)current.ai_addr
                ipv6 := core.IPv6_Address(addr_in6.sin6_addr.s6_addr)
                append(&addresses, ipv6)
            }

            current = current.ai_next
        }

        return addresses[:], nil

    } else when ODIN_OS == .Windows {
        hints := ADDRINFOA{
            ai_family = AF_INET6,  // IPv6 only
            ai_socktype = SOCK_STREAM,
        }

        result: ^ADDRINFOA
        err := GetAddrInfoA(cname, nil, &hints, &result)
        if err != 0 {
            return nil, core.DNS_Error.NAME_NOT_FOUND
        }
        defer FreeAddrInfoA(result)

        addresses := make([dynamic]core.IPv6_Address)

        current := result
        for current != nil {
            if current.ai_family == AF_INET6 {
                addr_in6 := cast(^SOCKADDR_IN6)current.ai_addr
                ipv6 := core.IPv6_Address(addr_in6.sin6_addr.s6_addr)
                append(&addresses, ipv6)
            }

            current = current.ai_next
        }

        return addresses[:], nil
    }
}

// Reverse DNS lookup (IP to hostname)
lookup_addr :: proc(ip: core.IP_Address) -> (string, core.Network_Error) {
    // TODO: Implement reverse DNS lookup using getnameinfo
    return "", core.DNS_Error.NO_DATA
}

// Helper functions

// Check if a string is a valid IP address
is_ip :: proc(s: string) -> bool {
    _, ok := core.parse_ip(s)
    return ok
}

// Check if a string is a valid IPv4 address
is_ipv4 :: proc(s: string) -> bool {
    _, ok := core.parse_ipv4(s)
    return ok
}

// Check if a string is a valid IPv6 address
is_ipv6 :: proc(s: string) -> bool {
    _, ok := core.parse_ipv6(s)
    return ok
}

// Resolve a host:port string, performing DNS lookup if needed
resolve_tcp_addr :: proc(network: string, address: string) -> (core.TCP_Endpoint, core.Network_Error) {
    endpoint, ok := core.parse_endpoint(address)
    if !ok {
        return {}, core.Address_Error.INVALID_ADDRESS
    }

    // If it's already an IP address, return as-is
    addr_str := core.ip_to_string(endpoint.address)
    if is_ip(addr_str) {
        return core.make_tcp_endpoint(endpoint.address, endpoint.port), nil
    }

    // Otherwise, resolve the hostname
    dns_result, err := lookup_host(addr_str)
    if err != nil {
        return {}, err
    }

    if len(dns_result.addresses) == 0 {
        return {}, core.DNS_Error.NAME_NOT_FOUND
    }

    // Return the first address
    return core.make_tcp_endpoint(dns_result.addresses[0], endpoint.port), nil
}

// Resolve a host:port string for UDP
resolve_udp_addr :: proc(network: string, address: string) -> (core.UDP_Endpoint, core.Network_Error) {
    endpoint, ok := core.parse_endpoint(address)
    if !ok {
        return {}, core.Address_Error.INVALID_ADDRESS
    }

    // If it's already an IP address, return as-is
    addr_str := core.ip_to_string(endpoint.address)
    if is_ip(addr_str) {
        return core.make_udp_endpoint(endpoint.address, endpoint.port), nil
    }

    // Otherwise, resolve the hostname
    dns_result, err := lookup_host(addr_str)
    if err != nil {
        return {}, err
    }

    if len(dns_result.addresses) == 0 {
        return {}, core.DNS_Error.NAME_NOT_FOUND
    }

    // Return the first address
    return core.make_udp_endpoint(dns_result.addresses[0], endpoint.port), nil
}