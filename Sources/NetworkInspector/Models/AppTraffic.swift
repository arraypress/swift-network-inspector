//
//  AppTraffic.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  Processes summed by the app they belong to: Chrome and its dozen
//  helpers are one line. A process outside any .app is its own line.
//

import Foundation

/// One app's (or one bare process's) traffic over a window.
public struct AppTraffic: Codable, Sendable, Equatable {

    /// The app's display name, or the process's name.
    public let name: String

    /// The app's bundle identifier, when there is an app.
    public let bundleIdentifier: String?

    /// The app's path, or the executable's.
    public let path: String?

    /// The processes summed into this line.
    public let pids: [Int32]

    /// Bytes received in the window.
    public let bytesIn: Int64

    /// Bytes sent in the window.
    public let bytesOut: Int64

    /// Bytes received per second.
    public let inPerSecond: Double

    /// Bytes sent per second.
    public let outPerSecond: Double

    public init(name: String, bundleIdentifier: String?, path: String?, pids: [Int32], bytesIn: Int64,
                bytesOut: Int64, inPerSecond: Double, outPerSecond: Double) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.pids = pids
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.inPerSecond = inPerSecond
        self.outPerSecond = outPerSecond
    }
}
