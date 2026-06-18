import Foundation

public enum MultipartError: Error, Sendable, Equatable, CustomStringConvertible {
    case httpNotOK(statusCode: Int)
    case invalidRootContentType
    case missingBoundary
    case malformedBoundary
    case malformedPartHeaders
    case unexpectedBytesAfterPartBoundary
    case bufferExceeded(maxBytes: Int)
    case unexpectedEndOfStream
    /// A new URLSession part response arrived before the previous part’s `Content-Length` bytes were received.
    case urlSessionPartIncomplete
    /// An encapsulation boundary appears inside a part before its declared `Content-Length` bytes are consumed.
    case boundaryBeforeContentLengthEnd(contentLength: Int, boundaryOffset: Int)
    /// Bytes remain in the entity after all MIME parts were consumed.
    case unconsumedTrailingBytes(count: Int)

    public var description: String {
        switch self {
        case let .httpNotOK(statusCode):
            "HTTP response status \(statusCode) is not OK"
        case .invalidRootContentType:
            "Content-Type is not multipart/related"
        case .missingBoundary:
            "Content-Type is missing the boundary parameter"
        case .malformedBoundary:
            "Content-Type boundary parameter is malformed"
        case .malformedPartHeaders:
            "Multipart part headers are malformed or missing the header/body separator"
        case .unexpectedBytesAfterPartBoundary:
            "Unexpected bytes after a multipart part boundary"
        case let .bufferExceeded(maxBytes):
            "Multipart body exceeded the maximum buffer size (\(maxBytes) bytes)"
        case .unexpectedEndOfStream:
            "Multipart body ended before a complete part was received"
        case .urlSessionPartIncomplete:
            "Previous multipart part ended before its Content-Length bytes were received"
        case let .boundaryBeforeContentLengthEnd(contentLength, boundaryOffset):
            "Multipart encapsulation boundary at byte \(boundaryOffset) of the part body precedes the declared Content-Length (\(contentLength) bytes)"
        case let .unconsumedTrailingBytes(count):
            "Multipart body has \(count) unconsumed trailing byte(s) after all parts were parsed"
        }
    }

    public var humanReadableDescription: String { description }
}
