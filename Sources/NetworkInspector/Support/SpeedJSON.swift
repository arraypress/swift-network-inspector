//
//  SpeedJSON.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  `networkQuality -c` as a result. Throughputs are bits per second,
//  latencies milliseconds. A parallel run reports one `responsiveness`; a
//  sequential one (`-s`, and so also `-u` or `-d`) reports
//  `dl_responsiveness` and `ul_responsiveness` instead. A failed run
//  still exits 0 and prints JSON — with `error_code` and `error_domain` —
//  so the error has to be read from the document, not the exit status.
//

import Foundation

enum SpeedJSON {

    /// The result in one document.
    ///
    /// - Throws: ``NetworkInspectorError/speedTestFailed(domain:code:)`` for
    ///   a document carrying an error; ``NetworkInspectorError/unreadableOutput(tool:reason:)``
    ///   for anything that is not a JSON object.
    static func result(_ data: Data) throws -> SpeedResult {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkInspectorError.unreadableOutput(tool: "networkQuality", reason: "not a JSON object")
        }
        if let code = number(object["error_code"]) {
            throw NetworkInspectorError.speedTestFailed(domain: object["error_domain"] as? String ?? "unknown",
                                                        code: Int(code))
        }
        let parallel = number(object["responsiveness"])
        let down = number(object["dl_responsiveness"])
        let up = number(object["ul_responsiveness"])
        let score = parallel ?? [down, up].compactMap { $0 }.min()
        let start = object["start_date"] as? String
        let end = object["end_date"] as? String
        let options = object["cli_options"] as? [String] ?? []
        return SpeedResult(
            downloadBitsPerSecond: number(object["dl_throughput"]),
            uploadBitsPerSecond: number(object["ul_throughput"]),
            responsiveness: parallel,
            downloadResponsiveness: down,
            uploadResponsiveness: up,
            rating: score.map(ResponsivenessRules.rating),
            idleLatencyMs: number(object["base_rtt"]),
            loadedLatencyMs: score.flatMap { $0 > 0 ? 60_000 / $0 : nil },
            interface: object["interface_name"] as? String,
            server: object["test_endpoint"] as? String,
            downloadBytes: number(object["dl_bytes_transferred"]).map { Int64($0) },
            uploadBytes: number(object["ul_bytes_transferred"]).map { Int64($0) },
            start: start,
            end: end,
            seconds: duration(from: start, to: end),
            sequential: parallel == nil && (down != nil || up != nil || options.contains("-s"))
        )
    }

    /// A JSON number as a Double; nil for anything else.
    static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
        return value.doubleValue
    }

    /// Seconds between networkQuality's two local timestamps
    /// (`2026-10-18 22:32:36.336`).
    static func duration(from start: String?, to end: String?) -> Double? {
        guard let start, let end else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        guard let a = formatter.date(from: start), let b = formatter.date(from: end), b >= a else { return nil }
        return b.timeIntervalSince(a)
    }
}
