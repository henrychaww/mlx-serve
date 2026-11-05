import Foundation

/// A conservative admission floor, not a prediction of the job's peak.
enum ExternalMediaMemory {
    static func weightBytes(for files: [URL]) -> UInt64? {
        guard !files.isEmpty else { return nil }
        var seen = Set<String>()
        var total: UInt64 = 0
        for file in files {
            let path = file.standardizedFileURL.resolvingSymlinksInPath().path
            guard seen.insert(path).inserted else { continue }
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  attrs[.type] as? FileAttributeType == .typeRegular,
                  let size = attrs[.size] as? NSNumber, size.int64Value > 0 else { return nil }
            let (sum, overflow) = total.addingReportingOverflow(size.uint64Value)
            guard !overflow else { return nil }
            total = sum
        }
        return total > 0 ? total : nil
    }

    static func requiredBytes(weightBytes: UInt64) -> UInt64? {
        guard weightBytes > 0 else { return nil }
        let headroom = max(weightBytes / 4, UInt64(2) << 30)
        let (result, overflow) = weightBytes.addingReportingOverflow(headroom)
        return overflow ? nil : result
    }

    static func hasEnough(available: UInt64, required: UInt64) -> Bool {
        available > 0 && required > 0 && available >= required
    }
}
