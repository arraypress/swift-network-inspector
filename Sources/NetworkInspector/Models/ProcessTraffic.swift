//
//  ProcessTraffic.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What one process sent and received during a measurement window.
public struct ProcessTraffic: Codable, Sendable, Equatable {

    /// Who it is.
    public let process: ProcessIdentity

    /// Bytes received in the window.
    public let bytesIn: Int64

    /// Bytes sent in the window.
    public let bytesOut: Int64

    /// Bytes received per second over the window.
    public let inPerSecond: Double

    /// Bytes sent per second over the window.
    public let outPerSecond: Double

    public init(process: ProcessIdentity, bytesIn: Int64, bytesOut: Int64, inPerSecond: Double, outPerSecond: Double) {
        self.process = process
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.inPerSecond = inPerSecond
        self.outPerSecond = outPerSecond
    }
}
