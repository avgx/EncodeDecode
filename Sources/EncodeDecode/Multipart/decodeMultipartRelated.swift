import Foundation



/// Decodes JSON objects from each body part of a buffered `multipart/related` entity.
///
/// Uses ``MultipartContentType`` for the `boundary` parameter and ``MultipartBodyParser`` for RFC 2046 encapsulation.
public func decodeMultipartRelated<T: Decodable & Sendable>(_ type: T.Type, contentType: String, from data: Data, using decoder: JSONDecoder) throws -> [T] {
    let parsed = try MultipartContentType.parse(from: contentType)
    guard parsed.mediaType == "multipart/related" else {
        throw MultipartError.invalidRootContentType
    }

    var parser = MultipartBodyParser(boundary: parsed.boundary)
    var frames = try parser.append(data)
    frames += try parser.finishCompleteMultipartBody()
    _ = try parser.finish(allowIncomplete: true)

    var parts: [T] = []
    parts.reserveCapacity(frames.count)
    for frame in frames {
        parts.append(try decoder.decode(T.self, from: frame.body))
    }
    return parts
}
