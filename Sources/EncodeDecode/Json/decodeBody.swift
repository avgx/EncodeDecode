import Foundation

/// Marker protocol to identify Optional types at runtime.
/// This protocol has no requirements - it only serves as a compile-time and runtime tag.
protocol OptionalDecoding {}

/// Extend all Optional types to conform to OptionalDecoding.
/// This allows the decodeBody function to detect whether T is an Optional type
/// by checking `T.self is OptionalDecoding.Type`.
extension Optional: OptionalDecoding {}

/// Decodes HTTP response data into the expected type T.
/// - Parameters:
///   - data: The raw Data received from the HTTP response
///   - decoder: The JSONDecoder to use for decoding
/// - Returns: Decoded value of type T
/// - Throws: URLError.badServerResponse if string decoding fails, or any decoding errors from JSONDecoder
public func decodeBody<T: Decodable & Sendable>(_ data: Data, using decoder: JSONDecoder) async throws -> T {
    // CRITICAL: Handle empty response bodies for Optional types
    // This is the core "OptionalDecoding" logic:
    // If response body is empty AND the expected type T is Optional (e.g., User?),
    // return nil instead of attempting to decode empty JSON (which would fail).
    if data.isEmpty, T.self is OptionalDecoding.Type {
        // Force-cast is safe here because:
        // 1. We verified T is Optional via the OptionalDecoding marker
        // 2. Optional<Decodable>.none is the universal nil value
        // 3. Any Optional type can be represented as Optional<Decodable>.none
        return Optional<Decodable>.none as! T
    }
    // If expected type is Data, return raw bytes unchanged
    else if T.self == Data.self {
        return data as! T
    }
    // If expected type is String, attempt UTF-8 conversion
    else if T.self == String.self {
        guard let string = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return string as! T
    }
    // For all other Decodable types (including Optional types with non-empty data):
    // Decode JSON asynchronously to avoid blocking the current thread
    else {
        return try await Task.detached {
            try decoder.decode(T.self, from: data)
        }.value
    }
}
