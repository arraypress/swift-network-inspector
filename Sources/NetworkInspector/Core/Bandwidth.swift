//
//  Bandwidth.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  Per-process bandwidth from nettop — the only public source of
//  per-process byte counts on macOS (the NetworkStatistics framework it
//  reads is private). nettop sees every process, root's included, without
//  root. Its counters are cumulative, so a rate is the difference between
//  two samples over nettop's own timestamps.
//
//  By default only traffic that crosses a real interface is counted
//  (`-t external`): loopback is a Mac talking to itself, and a VPN client
//  can move gigabytes over it (measured: 2.7 GB each way for one).
//

import Foundation

public enum Bandwidth {

    /// Traffic per process and per app over one window.
    ///
    /// - Parameters:
    ///   - seconds: The window, whole seconds (nettop takes no fractions).
    ///   - includeLoopback: Count traffic between local processes too.
    /// - Throws: ``NetworkInspectorError``.
    public static func measure(seconds: Int = 1, includeLoopback: Bool = false) throws -> TrafficReport {
        var report: TrafficReport?
        let window = max(1, seconds)
        try stream(seconds: window, includeLoopback: includeLoopback, timeout: Double(window * 3 + 15)) { found in
            report = found
            return false
        }
        guard let report else {
            throw NetworkInspectorError.toolFailed(tool: "nettop", reason: "it stopped after one sample")
        }
        return report
    }

    /// One report per window, every `seconds`, until `body` returns false.
    ///
    /// - Throws: ``NetworkInspectorError``.
    public static func watch(seconds: Int, includeLoopback: Bool = false,
                             _ body: (TrafficReport) -> Bool) throws {
        try stream(seconds: max(1, seconds), includeLoopback: includeLoopback, timeout: nil, body)
    }

    /// Consecutive samples into reports; a pid is looked up once per run.
    private static func stream(seconds window: Int, includeLoopback: Bool, timeout: Double?,
                               _ body: (TrafficReport) -> Bool) throws {
        var previous: NettopSample?
        var identities: [Int32: ProcessIdentity] = [:]
        try NettopStream.run(arguments(seconds: window, includeLoopback: includeLoopback), timeout: timeout) { block in
            let sample = NettopCSV.sample(header: block.header, lines: block.lines, receivedAt: block.receivedAt)
            defer { previous = sample }
            guard let before = previous else { return true }
            let report = TrafficMath.report(before: before, after: sample, nominal: Double(window),
                                            includesLoopback: includeLoopback,
                                            endedAt: sample.receivedAt ?? Date()) { row in
                if let known = identities[row.pid] { return known }
                let found = ProcessLookup.identity(pid: row.pid, fallbackName: row.name)
                identities[row.pid] = found
                return found
            }
            return body(report)
        }
    }

    /// The nettop command line: per-process rows (`-P`), CSV logging until
    /// stopped (`-L 0`), exact byte counts (`-x`), only the columns read.
    static func arguments(seconds: Int, includeLoopback: Bool) -> [String] {
        ["-P", "-L", "0", "-x", "-s", String(seconds), "-J", "time,bytes_in,bytes_out"]
            + (includeLoopback ? [] : ["-t", "external"])
    }
}
