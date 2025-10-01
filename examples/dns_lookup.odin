package main

import "core:fmt"
import "../dns"
import "../core"
import "../platform"

// DNS lookup example
main :: proc() {
    // Initialize networking (required on Windows)
    if err := platform.init_networking(); err != nil {
        fmt.println("Failed to initialize networking:", err)
        return
    }
    defer platform.cleanup_networking()

    // Lookup a hostname
    hostname := "google.com"
    fmt.println("Looking up", hostname)

    result, err := dns.lookup_host(hostname)
    if err != nil {
        fmt.println("DNS lookup failed:", err)
        return
    }

    fmt.println("Found", len(result.addresses), "addresses:")
    for addr in result.addresses {
        fmt.println("  ", core.ip_to_string(addr))
    }

    // IPv4 only lookup
    fmt.println("\nIPv4 addresses only:")
    ipv4_addrs, ipv4_err := dns.lookup_ipv4(hostname)
    if ipv4_err != nil {
        fmt.println("IPv4 lookup failed:", ipv4_err)
    } else {
        for addr in ipv4_addrs {
            fmt.println("  ", core.ipv4_to_string(addr))
        }
    }

    // IPv6 only lookup
    fmt.println("\nIPv6 addresses only:")
    ipv6_addrs, ipv6_err := dns.lookup_ipv6(hostname)
    if ipv6_err != nil {
        fmt.println("IPv6 lookup failed:", ipv6_err)
    } else {
        for addr in ipv6_addrs {
            fmt.println("  ", core.ipv6_to_string(addr))
        }
    }

    // Test IP address parsing
    fmt.println("\nTesting IP address parsing:")
    test_ips := []string{"192.168.1.1", "127.0.0.1", "::1", "2001:db8::1"}

    for ip_str in test_ips {
        ip, ok := core.parse_ip(ip_str)
        if ok {
            fmt.printf("  %s -> %s (IPv4: %v, IPv6: %v)\n",
                ip_str, core.ip_to_string(ip),
                core.is_ipv4(ip), core.is_ipv6(ip))
        } else {
            fmt.printf("  %s -> Invalid IP\n", ip_str)
        }
    }
}