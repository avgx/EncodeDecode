import Foundation

/// Incremental `multipart/*` body parser (RFC 2046 encapsulation boundaries).
public struct MultipartBodyParser: Sendable {
    private let dashBoundary: [UInt8]
    private let maxBufferBytes: Int
    private var buf: [UInt8] = []
    private var needsPreambleBoundary = true
    private var isClosed = false

    private enum Bytes {
        static let CR: UInt8 = 0x0D
        static let LF: UInt8 = 0x0A
        static let DASH: UInt8 = 0x2D

        static let CRLF: [UInt8] = [CR, LF]
        static let LFLF: [UInt8] = [LF, LF]
        static let CRLFCRLF: [UInt8] = CRLF + CRLF
        static let DASHDASH: [UInt8] = [DASH, DASH]
    }

    /// End of MIME part headers: canonical `\r\n\r\n`, or `\n\n` for LF-only payloads (common on disk / some servers).
    private static func headerBodySeparatorRange(in buf: [UInt8]) -> Range<Int>? {
        let cr = buf.firstRange(of: Bytes.CRLFCRLF)
        let lf = buf.firstRange(of: Bytes.LFLF)
        switch (cr, lf) {
        case (nil, nil): return nil
        case let (c?, nil): return c
        case (nil, let l?): return l
        case let (c?, l?): return c.lowerBound <= l.lowerBound ? c : l
        }
    }

    public init(boundary: String, maxBufferBytes: Int = 8_000_000) {
        var dash = Bytes.DASHDASH
        dash.append(contentsOf: boundary.utf8)
        self.dashBoundary = dash
        self.maxBufferBytes = maxBufferBytes
    }

    public mutating func append(_ chunk: Data) throws -> [MultipartFrame] {
        guard !isClosed else { return [] }
        buf.append(contentsOf: chunk)
        if buf.count > maxBufferBytes {
            throw MultipartError.bufferExceeded(maxBytes: maxBufferBytes)
        }
        var out: [MultipartFrame] = []
        while !isClosed {
            guard let frame = try extractOneFrame() else { break }
            out.append(frame)
        }
        return out
    }

    /// Called when the URLSession task completes. Incomplete trailing bytes are discarded without an error.
    public mutating func finish(allowIncomplete: Bool = true) throws -> [MultipartFrame] {
        guard !isClosed else { return [] }
        if buf.isEmpty { return [] }
        if allowIncomplete {
            buf.removeAll(keepingCapacity: false)
            return []
        }
        throw MultipartError.unexpectedEndOfStream
    }

    /// After the full entity is in memory, emits one final part when the body ends at EOF without a following encapsulation boundary (common for HTTP responses that omit the closing delimiter).
    public mutating func finishCompleteMultipartBody() throws -> [MultipartFrame] {
        guard !isClosed else { return [] }
        guard !buf.isEmpty else { return [] }

        if needsPreambleBoundary {
            guard let headerStart = findFirstPartHeaderStart() else {
                throw MultipartError.unexpectedEndOfStream
            }
            buf.removeSubrange(0..<headerStart)
            needsPreambleBoundary = false
        }

        guard let hdrRange = Self.headerBodySeparatorRange(in: buf) else {
            throw MultipartError.malformedPartHeaders
        }
        let headers = try Self.parsePartHeaders(Data(buf[0..<hdrRange.lowerBound]))
        let bodyStart = hdrRange.upperBound
        guard bodyStart <= buf.count else {
            throw MultipartError.malformedPartHeaders
        }

        let body: Data
        if let n = Self.parseContentLength(from: headers) {
            guard bodyStart + n <= buf.count else {
                throw MultipartError.unexpectedEndOfStream
            }
            guard bodyStart + n == buf.count else {
                throw MultipartError.unexpectedBytesAfterPartBoundary
            }
            body = Data(buf[bodyStart..<(bodyStart + n)])
        } else {
            body = Data(buf[bodyStart..<buf.count])
        }

        buf.removeAll(keepingCapacity: false)
        isClosed = true
        return [MultipartFrame(headers: headers, body: body)]
    }

    private mutating func extractOneFrame() throws -> MultipartFrame? {
        if isClosed { return nil }

        if needsPreambleBoundary {
            guard let headerStart = findFirstPartHeaderStart() else { return nil }
            buf.removeSubrange(0..<headerStart)
            needsPreambleBoundary = false
        }

        guard let hdrRange = Self.headerBodySeparatorRange(in: buf) else { return nil }
        let headersSlice = buf[0..<hdrRange.lowerBound]
        let bodyStart = hdrRange.upperBound
        guard bodyStart <= buf.count else { return nil }

        let headers = try Self.parsePartHeaders(Data(headersSlice))
        let cl = Self.parseContentLength(from: headers)

        let crlfNeedle = Bytes.CRLF + dashBoundary
        let lfNeedle = [Bytes.LF] + dashBoundary
        let endIdx: Int
        let needleLen: Int
        if let n = cl {
            guard bodyStart + n <= buf.count else { return nil }
            endIdx = bodyStart + n
            if endIdx + crlfNeedle.count <= buf.count,
               Array(buf[endIdx..<(endIdx + crlfNeedle.count)]) == crlfNeedle
            {
                needleLen = crlfNeedle.count
            } else if endIdx + lfNeedle.count <= buf.count,
                      Array(buf[endIdx..<(endIdx + lfNeedle.count)]) == lfNeedle
            {
                needleLen = lfNeedle.count
            } else {
                return nil
            }
        } else if let e = buf.indexOf(crlfNeedle, startingAt: bodyStart) {
            endIdx = e
            needleLen = crlfNeedle.count
        } else if let e = buf.indexOf(lfNeedle, startingAt: bodyStart) {
            endIdx = e
            needleLen = lfNeedle.count
        } else {
            return nil
        }

        let body = Data(buf[bodyStart..<endIdx])

        let afterDelimiter = endIdx + needleLen

        guard afterDelimiter <= buf.count else { return nil }
        if afterDelimiter == buf.count {
            return nil
        }

        let b0 = buf[afterDelimiter]
        if b0 == Bytes.DASH {
            guard afterDelimiter + 1 < buf.count else { return nil }
            guard buf[afterDelimiter + 1] == Bytes.DASH else {
                throw MultipartError.unexpectedBytesAfterPartBoundary
            }
            var cut = afterDelimiter + 2
            if cut + 1 < buf.count, buf[cut] == Bytes.CR, buf[cut + 1] == Bytes.LF {
                cut += 2
            } else if cut < buf.count, buf[cut] == Bytes.LF {
                cut += 1
            }
            buf.removeSubrange(0..<cut)
            isClosed = true
        } else if b0 == Bytes.CR {
            guard afterDelimiter + 1 < buf.count else { return nil }
            guard buf[afterDelimiter + 1] == Bytes.LF else {
                throw MultipartError.unexpectedBytesAfterPartBoundary
            }
            buf.removeSubrange(0..<afterDelimiter + 2)
        } else if b0 == Bytes.LF {
            buf.removeSubrange(0..<afterDelimiter + 1)
        } else {
            throw MultipartError.unexpectedBytesAfterPartBoundary
        }

        return MultipartFrame(headers: headers, body: body)
    }

    private static func parseContentLength(from headers: [String: String]) -> Int? {
        guard let raw = headers["content-length"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let n = Int(raw),
              n >= 0
        else {
            return nil
        }
        return n
    }

    private func findFirstPartHeaderStart() -> Int? {
        if buf.count >= dashBoundary.count + 2,
           Array(buf[0..<dashBoundary.count]) == dashBoundary,
           buf[dashBoundary.count] == Bytes.CR, buf[dashBoundary.count + 1] == Bytes.LF
        {
            return dashBoundary.count + 2
        }
        if buf.count >= dashBoundary.count + 1,
           Array(buf[0..<dashBoundary.count]) == dashBoundary,
           buf[dashBoundary.count] == Bytes.LF
        {
            return dashBoundary.count + 1
        }
        let patCRLF = Bytes.CRLF + dashBoundary + Bytes.CRLF
        if buf.count >= patCRLF.count, let r = buf.firstRange(of: patCRLF) {
            return r.upperBound
        }
        let patLF = [Bytes.LF] + dashBoundary + [Bytes.LF]
        if buf.count >= patLF.count, let r = buf.firstRange(of: patLF) {
            return r.upperBound
        }
        return nil
    }

    private static func parsePartHeaders(_ data: Data) throws -> [String: String] {
        guard let s = String(data: data, encoding: .isoLatin1) else {
            throw MultipartError.malformedPartHeaders
        }
        var out: [String: String] = [:]
        for line in s.split(separator: "\n", omittingEmptySubsequences: false) {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }
            if t.first == " " || t.first == "\t" { continue }
            guard let colon = t.firstIndex(of: ":") else {
                throw MultipartError.malformedPartHeaders
            }
            let name = String(t[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(t[t.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            out[name] = value
        }
        return out
    }
}

private extension [UInt8] {
    func firstRange(of needle: [UInt8]) -> Range<Int>? {
        guard !needle.isEmpty, count >= needle.count else { return nil }
        outer: for i in 0...(count - needle.count) {
            for j in 0..<needle.count {
                if self[i + j] != needle[j] { continue outer }
            }
            return i..<(i + needle.count)
        }
        return nil
    }

    func indexOf(_ needle: [UInt8], startingAt: Int) -> Int? {
        guard startingAt < count else { return nil }
        guard let r = Array(self[startingAt...]).firstRange(of: needle) else { return nil }
        return startingAt + r.lowerBound
    }
}
