import Testing
import Foundation
import EncodeDecode

@Test func bodyEncode_encodeData_passthrough() async throws {
    let input = Data([1, 2, 3])
    let output = try await encodeBody(input, using: JSONEncoder())

    #expect(output == input)
}

@Test func bodyEncode_encodeString_utf8() async throws {
    let output = try await encodeBody("hello", using: JSONEncoder())
    #expect(output == Data("hello".utf8))
}
