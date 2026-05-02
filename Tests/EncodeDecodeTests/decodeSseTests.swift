import Testing
import Foundation
import EncodeDecode

private struct DecodeModel: Codable, Sendable, Equatable {
    let name: String
}



@Test func bodyDecodeSSE_accumulator_multilineData_joinsWithNewline() {
    var acc = SSEAccumulator()
    #expect(acc.push("event: msg") == nil)
    #expect(acc.push("data: hello") == nil)
    #expect(acc.push("data: world") == nil)
    let ev = acc.push("")
    #expect(ev == ServerSentEvent(id: nil, event: "msg", data: "hello\nworld"))
}

@Test func bodyDecodeSSE_accumulator_finish_flushesLastBlock() {
    var acc = SSEAccumulator()
    #expect(acc.push("event: x") == nil)
    #expect(acc.push("data: {}") == nil)
    let ev = acc.finish()
    #expect(ev?.event == "x")
    #expect(ev?.data == "{}")
}

@Test func bodyDecodeSSE_decodeStreamData_roundTrip() throws {
    let body = """
    event: stream-data
    data: {"name":"n1"}

    event: stream-data
    data: {"name":"n2"}

    """.data(using: .utf8)!

    let out = try decodeSse(DecodeModel.self, from: body, using: JSONDecoder())
    #expect(out == [DecodeModel(name: "n1"), DecodeModel(name: "n2")])
}

@Test func bodyDecodeSSE_crlfOnlyLineTerminators_decodes() throws {
    let crlf = "\r\n"
    let text = "event: stream-data" + crlf + "data: {\"name\":\"crlf\"}" + crlf + crlf
    let body = Data(text.utf8)
    let out = try decodeSse(DecodeModel.self, from: body, using: JSONDecoder())
    #expect(out == [DecodeModel(name: "crlf")])
}

@Test func bodyDecodeSSE_endOfStream_stopsProcessingTail() throws {
    let body = """
    event: stream-data
    data: {"name":"only"}

    event: end-of-stream
    data: ignored

    event: stream-data
    data: {"name":"after"}

    """.data(using: .utf8)!

    let out = try decodeSse(DecodeModel.self, from: body, using: JSONDecoder())
    #expect(out == [DecodeModel(name: "only")])
}

@Test func bodyDecodeSSE_grpcError_throwsWithUserInfo() throws {
    let body = """
    event: grpc-error
    data: something failed

    """.data(using: .utf8)!

    var caught: URLError?
    do {
        _ = try decodeSse(DecodeModel.self, from: body, using: JSONDecoder())
    } catch let error as URLError {
        caught = error
    }
    #expect(caught != nil)
    #expect(caught?.userInfo["grpc-error"] as? String == "something failed")
}

@Test func bodyDecodeSSE_fixture_page2_twoStreamDataChunks() throws {
    let url = try #require(Bundle.module.url(forResource: "cameras_page2", withExtension: "sse"))
    let data = try Data(contentsOf: url)
    let pages = try decodeSse(CameraListPage.self, from: data, using: JSONDecoder())

    #expect(pages.count == 2)
    #expect(pages[0].items.count == 2)
    #expect(pages[1].items.isEmpty)
    #expect(pages[0].items.contains { $0.display_name == "Stairs" })
}

@Test func bodyDecodeSSE_fixture_full_singleLargeChunk() throws {
    let url = try #require(Bundle.module.url(forResource: "cameras_full", withExtension: "sse"))
    let data = try Data(contentsOf: url)
    let pages = try decodeSse(CameraListPage.self, from: data, using: JSONDecoder())

    #expect(pages.count == 1)
    #expect(pages[0].items.count > 2)
}
