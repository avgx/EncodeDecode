import Foundation

public struct DecodingErrorDescription: CustomStringConvertible, Sendable {
    public let summary: String
    public let path: String
    public let details: String

    public var description: String {
        """
        \(summary)

        Path:
        \(path)

        Details:
        \(details)
        """
    }
}

public extension DecodingError {

    var readableDescription: DecodingErrorDescription {
        switch self {

        case let .keyNotFound(key, context):
            return .init(
                summary: "Missing required key \"\(key.stringValue)\"",
                path: context.codingPath.prettyPath,
                details: context.debugDescription.cleanedDecodingDescription
            )

        case let .typeMismatch(type, context):
            return .init(
                summary: "Type mismatch for \(type)",
                path: context.codingPath.prettyPath,
                details: context.debugDescription.cleanedDecodingDescription
            )

        case let .valueNotFound(type, context):
            return .init(
                summary: "Missing value for \(type)",
                path: context.codingPath.prettyPath,
                details: context.debugDescription.cleanedDecodingDescription
            )

        case let .dataCorrupted(context):
            return .init(
                summary: "Corrupted or invalid data",
                path: context.codingPath.prettyPath,
                details: context.debugDescription.cleanedDecodingDescription
            )

        @unknown default:
            return .init(
                summary: "Unknown decoding error",
                path: "",
                details: String(describing: self)
            )
        }
    }

    var humanReadableDescription: String {
        readableDescription.description
    }
}

private extension Array where Element == CodingKey {

    var prettyPath: String {
        guard !isEmpty else {
            return "<root>"
        }

        var result = ""

        for key in self {
            if let index = key.intValue {
                result += "[\(index)]"
            } else {
                if result.isEmpty {
                    result = key.stringValue
                } else {
                    result += ".\(key.stringValue)"
                }
            }
        }

        return result
    }
}

private extension String {

    var cleanedDecodingDescription: String {
        self
            .replacingOccurrences(
                of: #"CodingKeys\(stringValue: "([^"]+)", intValue: nil\)"#,
                with: #""$1""#,
                options: .regularExpression
            )
    }
}
