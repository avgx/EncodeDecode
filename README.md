# EncodeDecode

Small Swift package for HTTP message bodies: JSON helpers, **Server-Sent Events** (`text/event-stream`), and buffered **`multipart/related`** with a proper RFC-style boundary parser.

- **Swift** 6.1+  
- **Platforms:** iOS 15+, macOS 13+, tvOS 15+, watchOS 9+, visionOS 1+

## Add the dependency

```swift
dependencies: [
    .package(url: "https://github.com/<you>/EncodeDecode.git", from: "1.0.0"),
],
targets: [
    .target(name: "YourApp", dependencies: ["EncodeDecode"]),
]
```

## JSON request / response bodies

`encodeBody` and `decodeBody` centralize common patterns when talking to JSON HTTP APIs.

| Input / expectation | Behavior |
|---------------------|----------|
| `Data` | Pass-through (`encodeBody` / `decodeBody`). |
| `String` | UTF-8 bytes (`encodeBody`); UTF-8 decode or `URLError.badServerResponse` (`decodeBody`). |
| Other `Encodable` / `Decodable` | `JSONEncoder` / `JSONDecoder` on a detached task (non-blocking for plain JSON). |
| Empty `Data` + `T?` | `decodeBody` returns `nil` without parsing JSON. |

```swift
import EncodeDecode

let payload = try await encodeBody(MyDTO(...), using: JSONEncoder())
let dto: MyDTO = try await decodeBody(data, using: JSONDecoder())
let maybe: MyDTO? = try await decodeBody(Data(), using: JSONDecoder()) // nil
```

## Server-Sent Events (`decodeSse`)

For bodies with `Content-Type: text/event-stream`. Line assembly follows the [WHATWG SSE](https://html.spec.whatwg.org/multipage/server-sent-events.html) model; bodies are split on `\r\n` when present so CRLF-only streams parse correctly.

Supported `event` names (contract used with some Axxon-style APIs):

| `event` | Effect |
|---------|--------|
| `stream-data` | `data` is decoded as JSON into `T` and appended to the result array. |
| `grpc-error` | Throws `URLError(.badServerResponse)` with `userInfo["grpc-error"]` set to the `data` string. |
| `end-of-stream` | Stops processing; following bytes are ignored. |
| `nil` (default message) | Ignored. |
| Any other name | Throws `URLError(.badServerResponse)`. |

Lower-level building blocks: `SSEAccumulator` and `ServerSentEvent` if you need incremental parsing.

## `multipart/related` (`decodeMultipartRelated`)

Decodes **one JSON value per MIME part** from a full response `Data` (not a streaming callback API).

1. **`Content-Type`** is parsed with `MultipartContentType.parse(from:)` (allowed roots include `multipart/related` and `multipart/x-mixed-replace`; this entry point **requires** `multipart/related` or it throws `MultipartError.invalidRootContentType`).
2. The **`boundary`** parameter is taken from the header (case-insensitive name; quoted values supported) with basic validation (RFC-oriented).
3. The body is parsed with `MultipartBodyParser` (RFC 2046 encapsulation). The last part may end at **EOF** without a closing `--boundary--` delimiter; a final open part is flushed via `finishCompleteMultipartBody()`.

Each part’s **payload** after part headers is passed to `JSONDecoder` as `T`. Part headers are available on `MultipartFrame` if you use the parser directly elsewhere.

```swift
import EncodeDecode

let items = try decodeMultipartRelated(Item.self, contentType: response.value(forHTTPHeaderField: "Content-Type")!, from: data, using: JSONDecoder())
```

`isMultipartRelated(_:)` returns whether the header’s first type token is `multipart/related` (cheap check before parsing).

### Multipart errors

`decodeMultipartRelated` and `MultipartContentType.parse` can throw `MultipartError` (`missingBoundary`, `malformedBoundary`, `invalidRootContentType`, etc.). Use `swift test` and the `BodyDecodeMultipartRelatedTests` cases as behavioral examples.

## Development

```bash
swift build
swift test
```

CI builds and tests on macOS with Swift 6.1 (see `.github/workflows/ci.yml`).
