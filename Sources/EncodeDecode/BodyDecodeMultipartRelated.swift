import Foundation

public func decodeMultipartRelated<T: Decodable & Sendable>(_ type: T.Type, contentType: String, from data: Data, using decoder: JSONDecoder) throws -> [T] {
    //let contentType = "multipart/related; boundary=ngpboundary"
    precondition(contentType.hasPrefix("multipart/related"))

    guard let boundary = contentType
        .split(separator: ";").last?.trimmingCharacters(in: .whitespaces)
        .split(separator: "=").last else {
        throw URLError(.badServerResponse)
    }
    let split = "\r\n--\(boundary)\r\n"
    guard let splitedBody = data.splitBy(boundary: split) else {
        throw URLError(.badServerResponse)
    }

    var parts: [T] = []

    for part in splitedBody {
        if let obj = part.removingMultipartHeaders() {
            let decoded = try decoder.decode(T.self, from: obj)
            parts.append(decoded)
        }
    }
    return parts
}

extension Data {
    func splitBy(boundary: String) -> [Data]? {
        guard let boundaryBytes = boundary.data(using: .utf8) else {
            return nil
        }

        var chunks: [Data] = []
        var pos = startIndex

        while let r = self[pos...].range(of: boundaryBytes) {
            if r.lowerBound > pos {
                chunks.append(self[pos..<r.lowerBound])
            }

            pos = r.upperBound
        }

        if pos < endIndex {
            chunks.append(self[pos...])
        }
        return chunks
    }

    func removingMultipartHeaders() -> Data? {
        let LF = "\r\n"
        let LFLF = (LF + LF).data(using: .utf8)!

        if let r = self.range(of: LFLF) {
            if r.upperBound < endIndex {
                let body = self[r.upperBound...]
                return body
            }
        }

        return nil
    }
}
