//
//  TrafficMath.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  From two cumulative samples to bytes moved and rates. nettop keeps a
//  process's total after its sockets close (measured: a 3,001,321-byte
//  download stayed counted after the socket closed), so the difference
//  between two samples is what moved in between.
//

import Foundation

enum TrafficMath {

    /// Bytes moved per process between two samples, zero rows left out.
    ///
    /// A pid only in `after` opened its sockets inside the window and counts
    /// from zero. A pid only in `before` has exited; what it moved since is
    /// lost. A counter that went down means the pid was reused, so the new
    /// process counts from zero.
    static func deltas(from before: NettopSample, to after: NettopSample) -> [NettopRow] {
        after.rows.values.compactMap { row in
            let previous = before.rows[row.pid]
            func moved(_ now: Int64, _ then: Int64?) -> Int64 {
                guard let then, now >= then else { return now }
                return now - then
            }
            let bytesIn = moved(row.bytesIn, previous?.bytesIn)
            let bytesOut = moved(row.bytesOut, previous?.bytesOut)
            guard bytesIn > 0 || bytesOut > 0 else { return nil }
            return NettopRow(name: row.name, pid: row.pid, bytesIn: bytesIn, bytesOut: bytesOut)
        }
    }

    /// The window's length: nettop's own timestamps where both samples have
    /// them (a day boundary between them is allowed for), else this
    /// process's clock, else `nominal`.
    static func elapsed(from before: NettopSample, to after: NettopSample, nominal: Double) -> Double {
        if let start = before.time, let end = after.time {
            var span = end - start
            if span < 0 { span += 86_400 }
            if span > 0 { return span }
        }
        if let start = before.receivedAt, let end = after.receivedAt, end > start {
            return end.timeIntervalSince(start)
        }
        return nominal
    }

    /// Biggest first by bytes in and out together; ties by name, then pid.
    static func ranked(_ processes: [ProcessTraffic]) -> [ProcessTraffic] {
        processes.sorted {
            let a = $0.bytesIn + $0.bytesOut, b = $1.bytesIn + $1.bytesOut
            if a != b { return a > b }
            if $0.process.displayName != $1.process.displayName {
                return $0.process.displayName < $1.process.displayName
            }
            return $0.process.pid < $1.process.pid
        }
    }

    /// Processes summed by app: every process inside the same .app is one
    /// line; one outside any app is grouped only with others running the
    /// same executable. Biggest first.
    static func apps(_ processes: [ProcessTraffic], seconds: Double) -> [AppTraffic] {
        var order: [String] = []
        var groups: [String: [ProcessTraffic]] = [:]
        for traffic in processes {
            let identity = traffic.process
            let key = identity.appPath ?? identity.path ?? "pid:\(identity.pid)"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(traffic)
        }
        let apps = order.map { key -> AppTraffic in
            let members = groups[key] ?? []
            let first = members[0].process
            let bytesIn = members.reduce(Int64(0)) { $0 + $1.bytesIn }
            let bytesOut = members.reduce(Int64(0)) { $0 + $1.bytesOut }
            return AppTraffic(name: first.displayName, bundleIdentifier: first.bundleIdentifier,
                              path: first.appPath ?? first.path, pids: members.map(\.process.pid).sorted(),
                              bytesIn: bytesIn, bytesOut: bytesOut,
                              inPerSecond: seconds > 0 ? Double(bytesIn) / seconds : 0,
                              outPerSecond: seconds > 0 ? Double(bytesOut) / seconds : 0)
        }
        return apps.sorted {
            let a = $0.bytesIn + $0.bytesOut, b = $1.bytesIn + $1.bytesOut
            return a != b ? a > b : $0.name < $1.name
        }
    }

    /// The report for one window, naming each pid through `identify`.
    static func report(before: NettopSample, after: NettopSample, nominal: Double, includesLoopback: Bool,
                       endedAt: Date, identify: (NettopRow) -> ProcessIdentity) -> TrafficReport {
        let seconds = elapsed(from: before, to: after, nominal: nominal)
        let processes = ranked(deltas(from: before, to: after).map { row in
            ProcessTraffic(process: identify(row), bytesIn: row.bytesIn, bytesOut: row.bytesOut,
                           inPerSecond: Double(row.bytesIn) / seconds, outPerSecond: Double(row.bytesOut) / seconds)
        })
        return TrafficReport(seconds: seconds, endedAt: endedAt, includesLoopback: includesLoopback,
                             processes: processes, apps: apps(processes, seconds: seconds),
                             bytesIn: processes.reduce(0) { $0 + $1.bytesIn },
                             bytesOut: processes.reduce(0) { $0 + $1.bytesOut })
    }
}
