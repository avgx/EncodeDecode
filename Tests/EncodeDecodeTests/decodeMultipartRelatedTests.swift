import Testing
import Foundation
import EncodeDecode

private struct PartModel: Codable, Sendable, Equatable {
    let name: String
}

@Test func decodeMultipartRelated_twoJsonParts_withoutClosingDelimiter() throws {
    let boundary = "testb"
    let contentType = "multipart/related; boundary=\(boundary)"

    var body = Data()
    body.append(contentsOf: "\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".utf8)
    body.append(Data(#"{"name":"a"}"#.utf8))
    body.append(contentsOf: "\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".utf8)
    body.append(Data(#"{"name":"b"}"#.utf8))

    let parts = try decodeMultipartRelated(PartModel.self, contentType: contentType, from: body, using: JSONDecoder())
    #expect(parts == [PartModel(name: "a"), PartModel(name: "b")])
}

@Test func decodeMultipartRelated_twoJsonParts_withClosingDelimiter() throws {
    let boundary = "testb"
    let contentType = "multipart/related; boundary=\(boundary)"

    var body = Data()
    body.append(contentsOf: "\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".utf8)
    body.append(Data(#"{"name":"a"}"#.utf8))
    body.append(contentsOf: "\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".utf8)
    body.append(Data(#"{"name":"b"}"#.utf8))
    body.append(contentsOf: "\r\n--\(boundary)--\r\n".utf8)

    let parts = try decodeMultipartRelated(PartModel.self, contentType: contentType, from: body, using: JSONDecoder())
    #expect(parts == [PartModel(name: "a"), PartModel(name: "b")])
}

@Test func decodeMultipartRelated_boundaryNotLastParameter() throws {
    let boundary = "aboundary"
    let contentType = "multipart/related; boundary=\(boundary); charset=utf-8"

    var body = Data()
    body.append(contentsOf: "\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".utf8)
    body.append(Data(#"{"name":"solo"}"#.utf8))

    let parts = try decodeMultipartRelated(PartModel.self, contentType: contentType, from: body, using: JSONDecoder())
    #expect(parts == [PartModel(name: "solo")])
}

@Test func decodeMultipartRelated_quotedBoundary() throws {
    let boundary = "qbound"
    let contentType = "multipart/related; boundary=\"\(boundary)\""

    var body = Data()
    body.append(contentsOf: "\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".utf8)
    body.append(Data(#"{"name":"q"}"#.utf8))

    let parts = try decodeMultipartRelated(PartModel.self, contentType: contentType, from: body, using: JSONDecoder())
    #expect(parts == [PartModel(name: "q")])
}

@Test func decodeMultipartRelated_boundaryParameterNameCaseInsensitive() throws {
    let boundary = "Bb"
    let contentType = "multipart/related; Boundary=\(boundary)"

    var body = Data()
    body.append(contentsOf: "\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".utf8)
    body.append(Data(#"{"name":"c"}"#.utf8))

    let parts = try decodeMultipartRelated(PartModel.self, contentType: contentType, from: body, using: JSONDecoder())
    #expect(parts == [PartModel(name: "c")])
}

@Test func decodeMultipartRelated_rejectsMixedReplace() throws {
    let contentType = "multipart/x-mixed-replace; boundary=x"
    let body = Data("--x\r\nContent-Type: application/json\r\n\r\n{}".utf8)

    #expect(throws: MultipartError.invalidRootContentType) {
        try decodeMultipartRelated(PartModel.self, contentType: contentType, from: body, using: JSONDecoder())
    }
}

@Test func isMultipartRelated_trueForSimpleHeader() {
    #expect(isMultipartRelated("multipart/related; boundary=a"))
}

@Test func isMultipartRelated_falseForMixedReplace() {
    #expect(!isMultipartRelated("multipart/x-mixed-replace; boundary=a"))
}

@Test func decodeMultipartRelated_lastPartUsesContentLengthWithoutClosingDelimiter() throws {
    let boundary = "clb"
    let contentType = "multipart/related; boundary=\(boundary)"

    var body = Data()
    body.append(contentsOf: "\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".utf8)
    body.append(Data(#"{"name":"first"}"#.utf8))
    let secondJson = #"{"name":"second"}"#
    body.append(contentsOf: "\r\n--\(boundary)\r\nContent-Type: application/json\r\nContent-Length: \(secondJson.utf8.count)\r\n\r\n".utf8)
    body.append(Data(secondJson.utf8))

    let parts = try decodeMultipartRelated(PartModel.self, contentType: contentType, from: body, using: JSONDecoder())
    #expect(parts == [PartModel(name: "first"), PartModel(name: "second")])
}

@Test func decodeMultipartRelated_page2_twoStreamDataChunks() throws {
    let url = try #require(Bundle.module.url(forResource: "cameras_page2", withExtension: "multipart"))
    let data = try Data(contentsOf: url)
    let pages = try decodeMultipartRelated(CameraListPage.self, contentType: "multipart/related; boundary=ngpboundary", from: data, using: JSONDecoder())

    // Fixture has three LF-terminated parts (list + two trailing empty pages).
    #expect(pages.count == 3)
    #expect(pages[0].items.count == 2)
    #expect(pages[1].items.isEmpty)
    #expect(pages[2].items.isEmpty)
    #expect(pages[0].items.contains { $0.display_name == "Stairs" })
}

@Test func decodeMultipartRelated_full_singleLargeChunk() throws {
    let url = try #require(Bundle.module.url(forResource: "cameras_full", withExtension: "multipart"))
    let data = try Data(contentsOf: url)
    let pages = try decodeMultipartRelated(CameraListPage.self, contentType: "multipart/related; boundary=ngpboundary", from: data, using: JSONDecoder())

    // Main list plus a trailing empty JSON part (same as live list tail responses).
    #expect(pages.count == 2)
    #expect(pages[0].items.count > 2)
    #expect(pages[1].items.isEmpty)
}
