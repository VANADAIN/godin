package main

import "core:fmt"
import "../udp"
import "../core"
import "../platform"

// Simple UDP echo server example
main :: proc() {
    // Initialize networking (required on Windows)
    if err := platform.init_networking(); err != nil {
        fmt.println("Failed to initialize networking:", err)
        return
    }
    defer platform.cleanup_networking()

    // Create a UDP listener
    conn, err := udp.listen("udp", "127.0.0.1:8081")
    if err != nil {
        fmt.println("Failed to listen on UDP:", err)
        return
    }
    defer udp.close(conn)

    fmt.println("UDP echo server listening on", udp.udp_local_addr(conn))

    for {
        // Read packet
        buffer := make([]u8, 1024)
        defer delete(buffer)

        bytes_read, sender_addr, read_err := udp.read_from(conn, buffer)
        if read_err != nil {
            fmt.println("Failed to read UDP packet:", read_err)
            continue
        }

        received := string(buffer[:bytes_read])
        fmt.println("Received from", core.endpoint_to_string(sender_addr), ":", received)

        // Echo back
        response := fmt.aprintf("Echo: %s", received)
        defer delete(response)

        bytes_written, write_err := udp.write_to(conn, transmute([]u8)response, sender_addr)
        if write_err != nil {
            fmt.println("Failed to send UDP response:", write_err)
            continue
        }

        fmt.println("Echoed", bytes_written, "bytes back")
    }
}