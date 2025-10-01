package main

import "core:fmt"
import "../url"

// URL parsing example
main :: proc() {
    test_urls := []string{
        "https://www.example.com:8080/path/to/resource?param1=value1&param2=value2#section",
        "http://user:pass@example.com/api/v1/users",
        "ftp://files.example.com/downloads/file.txt",
        "mailto:test@example.com",
        "/relative/path?query=test",
    }

    for url_str in test_urls {
        fmt.println("Parsing:", url_str)

        parsed_url, err := url.parse(url_str)
        if err != nil {
            fmt.println("  Error:", err)
            continue
        }

        fmt.println("  Scheme:", parsed_url.scheme)
        fmt.println("  Host:", parsed_url.host)
        fmt.println("  Hostname:", url.hostname(parsed_url))
        fmt.println("  Port:", url.port(parsed_url))
        fmt.println("  Path:", parsed_url.path)
        fmt.println("  Query:", parsed_url.raw_query)
        fmt.println("  Fragment:", parsed_url.fragment)

        if parsed_url.user != nil {
            fmt.println("  Username:", parsed_url.user.username)
            if parsed_url.user.password_set {
                fmt.println("  Password:", parsed_url.user.password)
            }
        }

        // Parse query parameters
        if len(parsed_url.raw_query) > 0 {
            fmt.println("  Query parameters:")
            params := url.parse_query(parsed_url.raw_query)
            for key, values in params {
                for value in values {
                    fmt.printf("    %s = %s\n", key, value)
                }
                delete(values)
            }
            delete(params)
        }

        // Convert back to string
        reconstructed := url.string(parsed_url)
        fmt.println("  Reconstructed:", reconstructed)
        delete(reconstructed)

        fmt.println()
    }

    // Test URL encoding/decoding
    fmt.println("URL encoding/decoding test:")
    test_strings := []string{
        "hello world",
        "special chars: !@#$%^&*()",
        "unicode: 你好世界",
        "mixed: hello world & 你好",
    }

    for s in test_strings {
        encoded := url.query_escape(s)
        decoded, decode_err := url.query_unescape(encoded)

        fmt.printf("  Original: %s\n", s)
        fmt.printf("  Encoded:  %s\n", encoded)
        if decode_err == nil {
            fmt.printf("  Decoded:  %s\n", decoded)
            delete(decoded)
        } else {
            fmt.printf("  Decode error: %v\n", decode_err)
        }
        delete(encoded)
        fmt.println()
    }
}