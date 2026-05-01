import Foundation

/// Encodes a value into Data suitable for HTTP request bodies.
/// - Parameters:
///   - value: The encodable value to encode (supports Data, String, or any Encodable)
///   - encoder: The JSONEncoder to use for encoding
/// - Returns: Encoded Data, or nil if the value cannot be encoded
public func encodeBody(_ value: Encodable & Sendable, using encoder: JSONEncoder) async throws -> Data? {
    // Check if the value is already raw Data - pass through as-is
    if let data = value as? Data {
        return data
    }
    // Check if the value is a plain string - convert to UTF-8 Data
    else if let string = value as? String {
        return string.data(using: .utf8)
    }
    // Otherwise, treat as a proper Encodable type (e.g., JSON) and encode asynchronously
    else {
        return try await Task.detached {
            try encoder.encode(value)
        }.value
    }
}
