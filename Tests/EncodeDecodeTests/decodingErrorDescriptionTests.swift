import Foundation
import Testing
import EncodeDecode

private struct NameModel: Codable, Sendable {
    let name: String
}

private struct CameraArchivePage: Codable, Sendable {
    struct Item: Codable, Sendable {
        struct ArchiveBinding: Codable, Sendable {
            struct Archive: Codable, Sendable {
                let name: String
                let incomplete: Bool
            }

            let archive: Archive
        }

        let archive_bindings: [ArchiveBinding]
    }

    let items: [Item]
}

private func decodeError<T: Decodable>(_ type: T.Type, from json: String) -> DecodingError {
    do {
        _ = try JSONDecoder().decode(type, from: Data(json.utf8))
        Issue.record("expected decode to fail")
        fatalError("unreachable")
    } catch let error as DecodingError {
        return error
    } catch {
        Issue.record("expected DecodingError, got \(error)")
        fatalError("unreachable")
    }
}

@Test func decodingErrorDescription_keyNotFound_nestedPath() {
    let json = """
    {
      "items": [{
        "archive_bindings": [{
          "archive": { "name": "x" }
        }]
      }]
    }
    """
    let error = decodeError(CameraArchivePage.self, from: json)
    let readable = error.readableDescription

    #expect(readable.summary == "Missing required key \"incomplete\"")
    #expect(readable.path == "items[0].archive_bindings[0].archive")
    #expect(readable.details.contains("incomplete"))
}

@Test func decodingErrorDescription_typeMismatch() {
    let error = decodeError(NameModel.self, from: #"{"name":123}"#)
    let readable = error.readableDescription

    #expect(readable.summary.hasPrefix("Type mismatch for"))
    #expect(readable.path == "name")
}

@Test func decodingErrorDescription_valueNotFound() {
    let error = decodeError(NameModel.self, from: #"{"name":null}"#)
    let readable = error.readableDescription

    #expect(readable.summary.hasPrefix("Missing value for"))
    #expect(readable.path == "name")
}

@Test func decodingErrorDescription_dataCorrupted() {
    let error = decodeError(NameModel.self, from: "{not json")
    let readable = error.readableDescription

    #expect(readable.summary == "Corrupted or invalid data")
}

@Test func decodingErrorDescription_malformedTopLevelPathIsRoot() {
    let error = decodeError(NameModel.self, from: "[]")
    let readable = error.readableDescription

    #expect(readable.path == "<root>")
}

@Test func decodingErrorDescription_formattedOutputContainsSections() {
    let error = decodeError(NameModel.self, from: #"{"name":null}"#)

    #expect(error.humanReadableDescription.contains("Path:"))
    #expect(error.humanReadableDescription.contains("Details:"))
    #expect(error.humanReadableDescription.contains(error.readableDescription.summary))
}

@Test func decodeSse_streamDataJsonFailureUsesReadableDescription() {
    let body = """
    event: stream-data
    data: {"name":123}

    """.data(using: .utf8)!

    do {
        _ = try decodeSse(NameModel.self, from: body, using: JSONDecoder())
        Issue.record("expected decode to fail")
    } catch let error as DecodingError {
        if case let .dataCorrupted(context) = error {
            #expect(context.debugDescription.contains("SSE stream-data decode failed:"))
            #expect(context.debugDescription.contains("Type mismatch"))
            #expect(context.debugDescription.contains("Path:"))
        } else {
            Issue.record("expected dataCorrupted, got \(error)")
        }
    } catch {
        Issue.record("expected DecodingError, got \(error)")
    }
}
