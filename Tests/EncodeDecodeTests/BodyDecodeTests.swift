import Testing
import Foundation
import EncodeDecode

private struct DecodeModel: Codable, Sendable, Equatable {
    let name: String
}

@Test func bodyDecode_decodeData_passthrough() async throws {
    let input = Data([9, 8, 7])
    let output: Data = try await decodeBody(input, using: JSONDecoder())

    #expect(output == input)
}

@Test func bodyDecode_decodeString_utf8() async throws {
    let output: String = try await decodeBody(Data("hello".utf8), using: JSONDecoder())
    #expect(output == "hello")
}

@Test func bodyDecode_decodeEmptyToOptionalNil() async throws {
    let output: String? = try await decodeBody(Data(), using: JSONDecoder())
    #expect(output == nil)
}

@Test func bodyDecode_decodeJSONModel() async throws {
    let input = Data(#"{"name":"alex"}"#.utf8)
    let output: DecodeModel = try await decodeBody(input, using: JSONDecoder())

    #expect(output == DecodeModel(name: "alex"))
}
