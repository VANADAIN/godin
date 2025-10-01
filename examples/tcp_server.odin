package main

import "core:fmt"
import "core:strings"
import "../tcp"
import "../platform"

// Simple TCP server example
main :: proc() {
    // Initialize networking (required on Windows)
    if err := platform.init_networking(); err != nil {
        fmt.println("Failed to initialize networking:", err)
        return
    }
    defer platform.cleanup_networking()

    // Create a TCP listener
    listener, err := tcp.listen("tcp", "127.0.0.1:8080")
    if err != nil {
        fmt.println("Failed to listen:", err)
        return
    }
    defer tcp.tcp_listener_close(listener)

    fmt.println("Server listening on", tcp.tcp_listener_addr(listener))

    for {
        // Accept incoming connections
        conn, accept_err := tcp.tcp_accept(listener)
        if accept_err != nil {
            fmt.println("Failed to accept connection:", accept_err)
            continue
        }

        fmt.println("New connection from", tcp.tcp_remote_addr(conn))

        // Handle the connection (in a real server, you'd spawn a goroutine/thread)
        handle_connection(conn)
    }
}

handle_connection :: proc(conn: ^tcp.TCP_Connection) {
    defer tcp.close(conn)

    // Read message from client
    buffer := make([]u8, 1024)
    defer delete(buffer)

    bytes_read, read_err := tcp.read(conn, buffer)
    if read_err != nil {
        fmt.println("Failed to read from client:", read_err)
        return
    }

    received := string(buffer[:bytes_read])
    fmt.println("Received:", received)

    // Send response
    response := "Hello from Odin TCP server!"
    bytes_written, write_err := tcp.write(conn, transmute([]u8)response)
    if write_err != nil {
        fmt.println("Failed to write to client:", write_err)
        return
    }

    fmt.println("Sent", bytes_written, "bytes to client")
}