import Foundation

/// Reads only bounded GGUF metadata; a file extension or name is not an architecture.
enum ExternalGGUF {
    static func isLTX25(at url: URL) -> Bool {
        guard let file = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? file.close() }
        guard let data = try? file.read(upToCount: 1_048_576) else { return false }
        return isLTX25(data)
    }

    static func isLTX25(_ data: Data) -> Bool {
        var reader = Reader(data: data)
        guard reader.bytes(count: 4) == Data("GGUF".utf8),
              let version = reader.number(bytes: 4), (2...3).contains(version),
              reader.number(bytes: 8) != nil,
              let count = reader.number(bytes: 8), count <= 4096 else { return false }
        var architecture: String?
        var modelVersion: String?
        for _ in 0..<count {
            guard let key = reader.string(), let type = reader.number(bytes: 4) else { return false }
            if type == 8 {
                guard let value = reader.string() else { return false }
                if key == "general.architecture" { architecture = value }
                if key == "model_version" { modelVersion = value }
            } else if !reader.skip(type: type, depth: 0) { return false }
        }
        return architecture == "ltxv" && (modelVersion == "2.5" || modelVersion?.hasPrefix("2.5.") == true)
    }

    private struct Reader {
        let data: Data
        var offset = 0

        mutating func bytes(count: Int) -> Data? {
            guard count >= 0, offset <= data.count, count <= data.count - offset else { return nil }
            defer { offset += count }
            return data.subdata(in: offset..<(offset + count))
        }

        mutating func number(bytes count: Int) -> UInt64? {
            guard let value = bytes(count: count) else { return nil }
            return value.enumerated().reduce(UInt64(0)) { $0 | (UInt64($1.element) << ($1.offset * 8)) }
        }

        mutating func string() -> String? {
            guard let length = number(bytes: 8), length <= 1_048_576,
                  let value = bytes(count: Int(length)) else { return nil }
            return String(data: value, encoding: .utf8)
        }

        mutating func skip(type: UInt64, depth: Int) -> Bool {
            switch type {
            case 0, 1, 7: return bytes(count: 1) != nil
            case 2, 3: return bytes(count: 2) != nil
            case 4, 5, 6: return bytes(count: 4) != nil
            case 10, 11, 12: return bytes(count: 8) != nil
            case 8: return string() != nil
            case 9:
                guard depth < 2, let elementType = number(bytes: 4),
                      let count = number(bytes: 8), count <= 100_000 else { return false }
                for _ in 0..<count where !skip(type: elementType, depth: depth + 1) { return false }
                return true
            default: return false
            }
        }
    }
}
