package main

import "core:fmt"
import "core:strings"
import "../tcp"
import "../platform"

// Simple TCP client example
main :: proc() {
    // Initialize networking (required on Windows)
    if err := platform.init_networking(); err != nil {
        fmt.println("Failed to initialize networking:", err)
        return
    }
    defer platform.cleanup_networking()

    // Connect to a TCP server
    conn, err := tcp.dial("tcp", "127.0.0.1:8080")
    if err != nil {
        fmt.println("Failed to connect:", err)
        return
    }
    defer tcp.close(conn)

    fmt.println("Connected to server at", tcp.tcp_remote_addr(conn))

    // Send a message
    message := "Hello from Odin TCP client!"
    bytes_written, write_err := tcp.write(conn, transmute([]u8)message)
    if write_err != nil {
        fmt.println("Failed to write:", write_err)
        return
    }
    fmt.println("Sent", bytes_written, "bytes")

    // Read response
    buffer := make([]u8, 1024)
    defer delete(buffer)

    bytes_read, read_err := tcp.read(conn, buffer)
    if read_err != nil {
        fmt.println("Failed to read:", read_err)
        return
    }

    response := string(buffer[:bytes_read])
    fmt.println("Received:", response)
}