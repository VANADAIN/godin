package godin_platform

import "core:c"
import "../core"

// Platform-specific socket operations
// This module provides low-level socket system calls for different operating systems

when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {

    // Linux/FreeBSD socket implementation
    foreign import libc "system:c"

    foreign libc {
        socket    :: proc(domain: c.int, type: c.int, protocol: c.int) -> c.int ---
        bind      :: proc(sockfd: c.int, addr: rawptr, addrlen: c.uint) -> c.int ---
        listen    :: proc(sockfd: c.int, backlog: c.int) -> c.int ---
        accept    :: proc(sockfd: c.int, addr: rawptr, addrlen: ^c.uint) -> c.int ---
        connect   :: proc(sockfd: c.int, addr: rawptr, addrlen: c.uint) -> c.int ---
        send      :: proc(sockfd: c.int, buf: rawptr, len: c.size_t, flags: c.int) -> c.ssize_t ---
        recv      :: proc(sockfd: c.int, buf: rawptr, len: c.size_t, flags: c.int) -> c.ssize_t ---
        sendto    :: proc(sockfd: c.int, buf: rawptr, len: c.size_t, flags: c.int, dest_addr: rawptr, addrlen: c.uint) -> c.ssize_t ---
        recvfrom  :: proc(sockfd: c.int, buf: rawptr, len: c.size_t, flags: c.int, src_addr: rawptr, addrlen: ^c.uint) -> c.ssize_t ---
        close     :: proc(fd: c.int) -> c.int ---
        setsockopt :: proc(sockfd: c.int, level: c.int, optname: c.int, optval: rawptr, optlen: c.uint) -> c.int ---
        getsockopt :: proc(sockfd: c.int, level: c.int, optname: c.int, optval: rawptr, optlen: ^c.uint) -> c.int ---
        fcntl     :: proc(fd: c.int, cmd: c.int, arg: c.int) -> c.int ---
    }

    // Socket address structures
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

    // Socket constants
    AF_INET     :: 2
    AF_INET6    :: 10
    AF_UNIX     :: 1

    SOCK_STREAM :: 1
    SOCK_DGRAM  :: 2
    SOCK_RAW    :: 3

    IPPROTO_TCP :: 6
    IPPROTO_UDP :: 17

    // Socket options
    SOL_SOCKET  :: 1
    SO_REUSEADDR :: 2
    SO_KEEPALIVE :: 9
    SO_RCVTIMEO :: 20
    SO_SNDTIMEO :: 21

} else when ODIN_OS == .Windows {

    // Windows socket implementation
    foreign import ws2_32 "system:ws2_32.lib"

    SOCKET :: distinct uintptr
    INVALID_SOCKET :: SOCKET(~uintptr(0))

    foreign ws2_32 {
        WSAStartup      :: proc(version: c.ushort, wsadata: rawptr) -> c.int ---
        WSACleanup      :: proc() -> c.int ---
        WSAGetLastError :: proc() -> c.int ---
        socket          :: proc(af: c.int, type: c.int, protocol: c.int) -> SOCKET ---
        bind            :: proc(s: SOCKET, name: rawptr, namelen: c.int) -> c.int ---
        listen          :: proc(s: SOCKET, backlog: c.int) -> c.int ---
        accept          :: proc(s: SOCKET, addr: rawptr, addrlen: ^c.int) -> SOCKET ---
        connect         :: proc(s: SOCKET, name: rawptr, namelen: c.int) -> c.int ---
        send            :: proc(s: SOCKET, buf: rawptr, len: c.int, flags: c.int) -> c.int ---
        recv            :: proc(s: SOCKET, buf: rawptr, len: c.int, flags: c.int) -> c.int ---
        sendto          :: proc(s: SOCKET, buf: rawptr, len: c.int, flags: c.int, to: rawptr, tolen: c.int) -> c.int ---
        recvfrom        :: proc(s: SOCKET, buf: rawptr, len: c.int, flags: c.int, from: rawptr, fromlen: ^c.int) -> c.int ---
        closesocket     :: proc(s: SOCKET) -> c.int ---
        setsockopt      :: proc(s: SOCKET, level: c.int, optname: c.int, optval: rawptr, optlen: c.int) -> c.int ---
        getsockopt      :: proc(s: SOCKET, level: c.int, optname: c.int, optval: rawptr, optlen: ^c.int) -> c.int ---
    }

    // Windows socket address structures (similar to Unix)
    sockaddr :: struct {
        sa_family: c.ushort,
        sa_data:   [14]c.char,
    }

    sockaddr_in :: struct {
        sin_family: c.short,
        sin_port:   c.ushort,
        sin_addr:   in_addr,
        sin_zero:   [8]c.char,
    }

    sockaddr_in6 :: struct {
        sin6_family:   c.short,
        sin6_port:     c.ushort,
        sin6_flowinfo: c.ulong,
        sin6_addr:     in6_addr,
        sin6_scope_id: c.ulong,
    }

    in_addr :: struct {
        s_addr: c.ulong,
    }

    in6_addr :: struct {
        s6_addr: [16]c.uchar,
    }

    // Windows socket constants
    AF_INET     :: 2
    AF_INET6    :: 23
    AF_UNIX     :: 1

    SOCK_STREAM :: 1
    SOCK_DGRAM  :: 2
    SOCK_RAW    :: 3

    IPPROTO_TCP :: 6
    IPPROTO_UDP :: 17

    SOL_SOCKET  :: 0xFFFF
    SO_REUSEADDR :: 0x0004
    SO_KEEPALIVE :: 0x0008
    SO_RCVTIMEO :: 0x1006
    SO_SNDTIMEO :: 0x1005

} else {
    #panic("Unsupported operating system")
}

// Cross-platform socket creation
create_socket :: proc(family: core.Address_Family, sock_type: core.Socket_Type, protocol: int) -> (core.Socket, core.Network_Error) {
    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        af := int(family)
        st := int(sock_type)

        fd := socket(c.int(af), c.int(st), c.int(protocol))
        if fd < 0 {
            return core.Socket(-1), core.System_Error.SYSTEM_ERROR
        }

        return core.Socket(fd), nil

    } else when ODIN_OS == .Windows {
        af := int(family)
        st := int(sock_type)

        s := socket(c.int(af), c.int(st), c.int(protocol))
        if s == INVALID_SOCKET {
            return core.Socket(-1), core.System_Error.SYSTEM_ERROR
        }

        return core.Socket(uintptr(s)), nil
    }
}

// Cross-platform socket close
close_socket :: proc(sock: core.Socket) -> core.Network_Error {
    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        if close(c.int(sock)) < 0 {
            return core.System_Error.SYSTEM_ERROR
        }
        return nil

    } else when ODIN_OS == .Windows {
        if closesocket(SOCKET(sock)) != 0 {
            return core.System_Error.SYSTEM_ERROR
        }
        return nil
    }
}

// Convert core.IP_Address to platform sockaddr
ip_to_sockaddr :: proc(ep: core.Endpoint) -> (addr: rawptr, len: c.uint) {
    when ODIN_OS == .Linux || ODIN_OS == .FreeBSD {
        switch ip in ep.address {
        case core.IPv4_Address:
            addr_in := new(sockaddr_in)
            addr_in.sin_family = AF_INET
            addr_in.sin_port = c.ushort(swap_bytes(ep.port))  // Network byte order
            addr_in.sin_addr.s_addr = transmute(c.uint)ip
            return addr_in, size_of(sockaddr_in)

        case core.IPv6_Address:
            addr_in6 := new(sockaddr_in6)
            addr_in6.sin6_family = AF_INET6
            addr_in6.sin6_port = c.ushort(swap_bytes(ep.port))  // Network byte order
            addr_in6.sin6_addr.s6_addr = transmute([16]c.uchar)ip
            return addr_in6, size_of(sockaddr_in6)
        }

    } else when ODIN_OS == .Windows {
        switch ip in ep.address {
        case core.IPv4_Address:
            addr_in := new(sockaddr_in)
            addr_in.sin_family = AF_INET
            addr_in.sin_port = c.ushort(swap_bytes(ep.port))  // Network byte order
            addr_in.sin_addr.s_addr = transmute(c.ulong)ip
            return addr_in, c.uint(size_of(sockaddr_in))

        case core.IPv6_Address:
            addr_in6 := new(sockaddr_in6)
            addr_in6.sin6_family = AF_INET6
            addr_in6.sin6_port = c.ushort(swap_bytes(ep.port))  // Network byte order
            addr_in6.sin6_addr.s6_addr = transmute([16]c.uchar)ip
            return addr_in6, c.uint(size_of(sockaddr_in6))
        }
    }

    return nil, 0
}

// Helper to swap bytes for network byte order
swap_bytes :: proc(x: u16) -> u16 {
    return (x << 8) | (x >> 8)
}

// Initialize platform networking (needed for Windows)
init_networking :: proc() -> core.Network_Error {
    when ODIN_OS == .Windows {
        wsadata: [256]u8  // WSADATA structure is about 256 bytes
        result := WSAStartup(0x0202, raw_data(wsadata[:]))  // Version 2.2
        if result != 0 {
            return core.System_Error.SYSTEM_ERROR
        }
    }
    return nil
}

// Cleanup platform networking (needed for Windows)
cleanup_networking :: proc() {
    when ODIN_OS == .Windows {
        WSACleanup()
    }
}