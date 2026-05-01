import Foundation

/// Parsed root `Content-Type` for an allowed multipart MJPEG stream.
public struct MultipartContentType: Sendable {
    /// Lowercased root type, e.g. `multipart/x-mixed-replace`.
    public let mediaType: String
    public let boundary: String
    
    private static let allowedTypes: Set<String> = [
        "multipart/x-mixed-replace",
        "multipart/related",
    ]
}

public func isMultipartRelated(_ contentType: String) -> Bool {
    let head = contentType.split(separator: ";", omittingEmptySubsequences: false)
        .first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() } ?? ""
    return head == "multipart/related"
}

/// Parses the root `Content-Type` for multipart streams
extension MultipartContentType {
    /// Extracts root media type and `boundary` for an allowed multipart kind.
    public static func parse(from contentTypeHeader: String) throws -> MultipartContentType {
        let trimmed = contentTypeHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MultipartError.invalidRootContentType }

        var mediaType: String?
        var boundary: String?

        for raw in trimmed.split(separator: ";", omittingEmptySubsequences: false) {
            let part = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if part.isEmpty { continue }
            if mediaType == nil {
                mediaType = part.lowercased()
                continue
            }
            let kv = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard kv.count == 2 else { continue }
            if kv[0].lowercased() == "boundary" {
                var v = kv[1]
                if v.count >= 2, v.first == "\"", v.last == "\"" {
                    v.removeFirst()
                    v.removeLast()
                }
                boundary = v
            }
        }

        guard let mt = mediaType, Self.allowedTypes.contains(mt) else {
            throw MultipartError.invalidRootContentType
        }
        guard let b = boundary, !b.isEmpty else {
            throw MultipartError.missingBoundary
        }
        if b.count > 200 {
            throw MultipartError.malformedBoundary
        }
        if b.unicodeScalars.contains(where: { $0 == "\r" || $0 == "\n" }) {
            throw MultipartError.malformedBoundary
        }
        return MultipartContentType(mediaType: mt, boundary: b)
    }
}
