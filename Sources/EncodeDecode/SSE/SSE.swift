import Foundation

/// One SSE message after a blank line per [WHATWG](https://html.spec.whatwg.org/multipage/server-sent-events.html)
public struct ServerSentEvent: Sendable, Equatable {
    public var id: String?
    public var event: String?
    /// Concatenated `data:` lines with `\n` between them.
    public var data: String

    public init(id: String? = nil, event: String? = nil, data: String) {
        self.id = id
        self.event = event
        self.data = data
    }
}
