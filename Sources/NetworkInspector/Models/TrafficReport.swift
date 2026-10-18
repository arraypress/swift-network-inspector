//
//  TrafficReport.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Per-process and per-app traffic over one measurement window, biggest first.
public struct TrafficReport: Codable, Sendable, Equatable {

    /// The window's real length in seconds, from nettop's own timestamps.
    public let seconds: Double

    /// When the window ended.
    public let endedAt: Date

    /// Whether loopback traffic (this Mac talking to itself) is counted.
    public let includesLoopback: Bool

    /// Every process that moved bytes in the window, biggest first.
    public let processes: [ProcessTraffic]

    /// The same, summed by app, biggest first.
    public let apps: [AppTraffic]

    /// Bytes received in the window, all processes.
    public let bytesIn: Int64

    /// Bytes sent in the window, all processes.
    public let bytesOut: Int64

    public init(seconds: Double, endedAt: Date, includesLoopback: Bool, processes: [ProcessTraffic],
                apps: [AppTraffic], bytesIn: Int64, bytesOut: Int64) {
        self.seconds = seconds
        self.endedAt = endedAt
        self.includesLoopback = includesLoopback
        self.processes = processes
        self.apps = apps
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }

    /// Bytes received per second, all processes.
    public var inPerSecond: Double { seconds > 0 ? Double(bytesIn) / seconds : 0 }

    /// Bytes sent per second, all processes.
    public var outPerSecond: Double { seconds > 0 ? Double(bytesOut) / seconds : 0 }
}
