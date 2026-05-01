import Foundation

/// For `Content-Type: text/event-stream`.
///
/// Supported `event` names (Axxon-style):
/// - `stream-data` — JSON payload decoded as `T`
/// - `grpc-error` — throws ``URLError`` with `userInfo["grpc-error"]`
/// - `end-of-stream` — stops processing; trailing bytes are ignored (same as a closed stream)
///
/// Parsing follows [WHATWG Server-Sent Events](https://html.spec.whatwg.org/multipage/server-sent-events.html) via ``SSEEventAccumulator``.
public func decodeSse<T: Decodable & Sendable>(_ type: T.Type, from data: Data, using decoder: JSONDecoder) throws -> [T] {
    guard let text = String(data: data, encoding: .utf8) else {
        throw URLError(.badServerResponse)
    }

    var parts: [T] = []
    var accumulator = SSEEventAccumulator()
    var stoppedAfterEndOfStream = false

    // Use explicit CRLF splitting: Swift `Character` may treat `\r\n` as one grapheme, so
    // `split(separator: "\n")` would not break lines on CRLF-only bodies (common for SSE).
    let lines: [String] = if text.contains("\r\n") {
        text.components(separatedBy: "\r\n")
    } else {
        text.components(separatedBy: "\n")
    }

    for line in lines {
        if stoppedAfterEndOfStream { break }
        if let sse = accumulator.push(line) {
            try decodeSseConsume(sse, type: type, decoder: decoder, parts: &parts, stopped: &stoppedAfterEndOfStream)
        }
    }

    if !stoppedAfterEndOfStream, let sse = accumulator.finish() {
        try decodeSseConsume(sse, type: type, decoder: decoder, parts: &parts, stopped: &stoppedAfterEndOfStream)
    }

    return parts
}

private func decodeSseConsume<T: Decodable & Sendable>(
    _ sse: SSEEvent,
    type: T.Type,
    decoder: JSONDecoder,
    parts: inout [T],
    stopped: inout Bool
) throws {
    switch sse.event {
    case "stream-data":
        let payload = Data(sse.data.utf8)
        parts.append(try decoder.decode(T.self, from: payload))
    case "grpc-error":
        throw URLError(.badServerResponse, userInfo: ["grpc-error": sse.data])
    case "end-of-stream":
        stopped = true
    case nil:
        break
    default:
        throw URLError(.badServerResponse)
    }
}
