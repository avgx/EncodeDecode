import Foundation

/// JSON body decode failure with the raw payload preserved for diagnostics.
public struct BodyDecodeError: Error, CustomStringConvertible, Sendable {
    public let payload: String
    public let decodingError: DecodingError

    public init(payload: String, decodingError: DecodingError) {
        self.payload = payload
        self.decodingError = decodingError
    }

    public var description: String {
        """
        \(decodingError.humanReadableDescription)

        Payload:
        \(payload)
        """
    }
}

public extension Error {

    /// Best-effort message for failed domain model loads (decode errors with optional payload).
    var domainLoadFailureLogMessage: String {
        if let bodyError = self as? BodyDecodeError {
            return bodyError.description
        }
        if let decodingError = self as? DecodingError {
            return decodingError.humanReadableDescription
        }
        return String(describing: self)
    }
}
