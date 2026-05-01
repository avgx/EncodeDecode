import Testing
import Foundation
import EncodeDecode

private struct PartModel: Codable, Sendable, Equatable {
    let name: String
}

@Test func bodyDecodeMultipartRelated_twoJsonParts() throws {
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
