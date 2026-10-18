//
//  NettopSample.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  One of nettop's per-process snapshots: cumulative byte counters for
//  every process it lists. Two of them, a window apart, make a rate.
//

import Foundation

/// One process's cumulative counters in one nettop sample.
public struct NettopRow: Codable, Sendable, Equatable {

    /// The name as nettop printed it — the kernel's, cut to 15 characters.
    public let name: String

    /// The process identifier: the part after the name's last dot.
    public let pid: Int32

    /// Bytes received since nettop first saw the process's sockets.
    public let bytesIn: Int64

    /// Bytes sent since then.
    public let bytesOut: Int64

    public init(name: String, pid: Int32, bytesIn: Int64, bytesOut: Int64) {
        self.name = name
        self.pid = pid
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }
}

/// One nettop sample.
public struct NettopSample: Codable, Sendable, Equatable {

    /// Seconds since local midnight, from nettop's `time` column, when present.
    public var time: Double?

    /// When this process read the sample, as a fallback clock.
    public var receivedAt: Date?

    /// The rows, by pid.
    public var rows: [Int32: NettopRow]

    public init(time: Double? = nil, receivedAt: Date? = nil, rows: [Int32: NettopRow] = [:]) {
        self.time = time
        self.receivedAt = receivedAt
        self.rows = rows
    }
}
