package godin_url

import "core:strings"
import "core:strconv"
import "core:unicode/utf8"

// URL parsing and manipulation for the Godin networking library
// Provides Go-style URL functionality with Odin type safety

// URL structure representing a parsed URL
URL :: struct {
    scheme:     string,
    user:       ^User_Info,
    host:       string,
    path:       string,
    raw_path:   string,
    force_query: bool,
    raw_query:  string,
    fragment:   string,
    raw_fragment: string,
}

// User information for URLs with authentication
User_Info :: struct {
    username: string,
    password: string,
    password_set: bool,
}

// URL parsing errors
URL_Error :: enum {
    INVALID_URL,
    INVALID_SCHEME,
    INVALID_HOST,
    INVALID_PORT,
    INVALID_PATH,
    INVALID_QUERY,
    INVALID_FRAGMENT,
    INVALID_ESCAPE,
}

// Parse a URL string into a URL structure
parse :: proc(raw_url: string) -> (URL, URL_Error) {
    url := URL{}

    remainder := raw_url

    // Parse scheme
    if scheme_end := strings.index(remainder, "://"); scheme_end != -1 {
        url.scheme = remainder[:scheme_end]
        remainder = remainder[scheme_end + 3:]

        // Validate scheme
        if !is_valid_scheme(url.scheme) {
            return {}, .INVALID_SCHEME
        }
    }

    // Parse fragment first (it comes last but we remove it early)
    if fragment_start := strings.index(remainder, "#"); fragment_start != -1 {
        url.fragment = remainder[fragment_start + 1:]
        remainder = remainder[:fragment_start]

        // TODO: Decode fragment
        url.raw_fragment = url.fragment
    }

    // Parse query
    if query_start := strings.index(remainder, "?"); query_start != -1 {
        url.raw_query = remainder[query_start + 1:]
        remainder = remainder[:query_start]
    }

    // Parse authority (user@host:port)
    if len(remainder) > 0 && remainder[0] != '/' {
        authority_end := strings.index(remainder, "/")
        if authority_end == -1 {
            authority_end = len(remainder)
        }

        authority := remainder[:authority_end]
        remainder = remainder[authority_end:]

        // Parse user info
        if user_end := strings.index(authority, "@"); user_end != -1 {
            user_info := authority[:user_end]
            authority = authority[user_end + 1:]

            // Parse username and password
            if pass_start := strings.index(user_info, ":"); pass_start != -1 {
                url.user = new(User_Info)
                url.user.username = user_info[:pass_start]
                url.user.password = user_info[pass_start + 1:]
                url.user.password_set = true
            } else {
                url.user = new(User_Info)
                url.user.username = user_info
                url.user.password_set = false
            }
        }

        // Parse host and port
        url.host = authority

        // Validate host
        if !is_valid_host(url.host) {
            return {}, .INVALID_HOST
        }
    }

    // The remainder is the path
    url.path = remainder
    url.raw_path = remainder

    return url, nil
}

// Convert URL back to string
string :: proc(url: URL) -> string {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    // Scheme
    if len(url.scheme) > 0 {
        strings.write_string(&builder, url.scheme)
        strings.write_string(&builder, "://")
    }

    // User info
    if url.user != nil {
        strings.write_string(&builder, url.user.username)
        if url.user.password_set {
            strings.write_byte(&builder, ':')
            strings.write_string(&builder, url.user.password)
        }
        strings.write_byte(&builder, '@')
    }

    // Host
    if len(url.host) > 0 {
        strings.write_string(&builder, url.host)
    }

    // Path
    if len(url.path) > 0 {
        strings.write_string(&builder, url.path)
    }

    // Query
    if len(url.raw_query) > 0 {
        strings.write_byte(&builder, '?')
        strings.write_string(&builder, url.raw_query)
    }

    // Fragment
    if len(url.fragment) > 0 {
        strings.write_byte(&builder, '#')
        strings.write_string(&builder, url.fragment)
    }

    return strings.clone(strings.to_string(builder))
}

// Get the hostname without port
hostname :: proc(url: URL) -> string {
    if colon := strings.index(url.host, ":"); colon != -1 {
        return url.host[:colon]
    }
    return url.host
}

// Get the port from the host, or return default port for scheme
port :: proc(url: URL) -> string {
    if colon := strings.index(url.host, ":"); colon != -1 {
        return url.host[colon + 1:]
    }

    // Return default port for common schemes
    switch url.scheme {
    case "http":
        return "80"
    case "https":
        return "443"
    case "ftp":
        return "21"
    case "ssh":
        return "22"
    case:
        return ""
    }
}

// Parse query parameters into a map
parse_query :: proc(query: string) -> map[string][]string {
    params := make(map[string][]string)

    if len(query) == 0 {
        return params
    }

    pairs := strings.split(query, "&")
    defer delete(pairs)

    for pair in pairs {
        if eq := strings.index(pair, "="); eq != -1 {
            key := pair[:eq]
            value := pair[eq + 1:]

            // URL decode key and value
            key_decoded, _ := query_unescape(key)
            value_decoded, _ := query_unescape(value)

            // Add to map
            if key_decoded in params {
                append(&params[key_decoded], value_decoded)
            } else {
                params[key_decoded] = make([]string, 1)
                params[key_decoded][0] = value_decoded
            }
        } else {
            // Key without value
            key_decoded, _ := query_unescape(pair)
            if key_decoded in params {
                append(&params[key_decoded], "")
            } else {
                params[key_decoded] = make([]string, 1)
                params[key_decoded][0] = ""
            }
        }
    }

    return params
}

// URL encoding/decoding

// Encode a string for use in URL query parameters
query_escape :: proc(s: string) -> string {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    for r in s {
        if should_escape_query(r) {
            // Convert to UTF-8 bytes and percent-encode
            utf8_bytes: [4]u8
            n := utf8.encode_rune(utf8_bytes[:], r)
            for i in 0..<n {
                strings.write_string(&builder, "%")
                strings.write_string(&builder, hex_upper(utf8_bytes[i]))
            }
        } else {
            strings.write_rune(&builder, r)
        }
    }

    return strings.clone(strings.to_string(builder))
}

// Decode a URL-encoded query string
query_unescape :: proc(s: string) -> (string, URL_Error) {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    i := 0
    for i < len(s) {
        if s[i] == '%' {
            if i + 2 >= len(s) {
                return "", .INVALID_ESCAPE
            }

            hex_str := s[i + 1:i + 3]
            byte_val, ok := strconv.parse_int(hex_str, 16)
            if !ok || byte_val < 0 || byte_val > 255 {
                return "", .INVALID_ESCAPE
            }

            strings.write_byte(&builder, u8(byte_val))
            i += 3
        } else if s[i] == '+' {
            strings.write_byte(&builder, ' ')
            i += 1
        } else {
            strings.write_byte(&builder, s[i])
            i += 1
        }
    }

    return strings.clone(strings.to_string(builder)), nil
}

// Join a base URL with a relative URL
resolve_reference :: proc(base: URL, ref: URL) -> URL {
    result := URL{}

    if len(ref.scheme) > 0 {
        // Absolute URL
        return ref
    }

    result.scheme = base.scheme
    result.user = base.user
    result.host = base.host

    if len(ref.path) == 0 {
        result.path = base.path
        result.raw_path = base.raw_path
        if len(ref.raw_query) == 0 {
            result.raw_query = base.raw_query
        } else {
            result.raw_query = ref.raw_query
        }
    } else {
        if strings.has_prefix(ref.path, "/") {
            result.path = ref.path
            result.raw_path = ref.raw_path
        } else {
            // Resolve relative path
            base_dir := base.path
            if last_slash := strings.last_index(base_dir, "/"); last_slash != -1 {
                base_dir = base_dir[:last_slash + 1]
            } else {
                base_dir = "/"
            }
            result.path = base_dir + ref.path
            result.raw_path = result.path
        }
        result.raw_query = ref.raw_query
    }

    result.fragment = ref.fragment
    result.raw_fragment = ref.raw_fragment

    return result
}

// Helper functions

// Check if a scheme is valid
is_valid_scheme :: proc(scheme: string) -> bool {
    if len(scheme) == 0 {
        return false
    }

    // First character must be a letter
    if !is_alpha(rune(scheme[0])) {
        return false
    }

    // Remaining characters must be letters, digits, or +-.
    for i in 1..<len(scheme) {
        c := rune(scheme[i])
        if !is_alpha(c) && !is_digit(c) && c != '+' && c != '-' && c != '.' {
            return false
        }
    }

    return true
}

// Check if a host is valid (simplified)
is_valid_host :: proc(host: string) -> bool {
    if len(host) == 0 {
        return false
    }

    // TODO: Implement proper host validation (IPv4, IPv6, domain names)
    return true
}

// Check if a character should be escaped in query parameters
should_escape_query :: proc(r: rune) -> bool {
    // Don't escape unreserved characters
    if is_alpha(r) || is_digit(r) {
        return false
    }

    switch r {
    case '-', '_', '.', '~':
        return false
    case:
        return true
    }
}

// Character classification helpers
is_alpha :: proc(r: rune) -> bool {
    return (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z')
}

is_digit :: proc(r: rune) -> bool {
    return r >= '0' && r <= '9'
}

// Convert byte to uppercase hex
hex_upper :: proc(b: u8) -> string {
    hex_chars := "0123456789ABCDEF"
    result: [2]u8
    result[0] = hex_chars[b >> 4]
    result[1] = hex_chars[b & 0xF]
    return string(result[:])
}