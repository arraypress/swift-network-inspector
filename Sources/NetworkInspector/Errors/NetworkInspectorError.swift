//
//  NetworkInspectorError.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why something in this library failed, in words a caller can print unchanged.
public enum NetworkInspectorError: Error, LocalizedError, Equatable, Sendable {

    /// A system tool could not be started, or stopped with an error.
    case toolFailed(tool: String, reason: String)

    /// A system tool's output was not in a shape this library reads.
    case unreadableOutput(tool: String, reason: String)

    /// This Mac has no Wi-Fi interface.
    case noWiFi

    /// The Wi-Fi scan failed; carries CoreWLAN's reason.
    case scanFailed(String)

    /// No interface by that name.
    case noSuchInterface(String)

    /// networkQuality ran and reported an error.
    case speedTestFailed(domain: String, code: Int)

    /// networkQuality did not finish in time.
    case timedOut(tool: String, seconds: Double)

    public var errorDescription: String? {
        switch self {
        case .toolFailed(let tool, let reason):
            return "\(tool) failed: \(reason)"
        case .unreadableOutput(let tool, let reason):
            return "\(tool)'s output was not understood: \(reason)"
        case .noWiFi:
            return "this Mac has no Wi-Fi interface"
        case .scanFailed(let reason):
            return "the Wi-Fi scan failed: \(reason)"
        case .noSuchInterface(let name):
            return "no network interface called \(name)"
        case .speedTestFailed(let domain, let code):
            return "networkQuality could not finish: \(domain) \(code)"
        case .timedOut(let tool, let seconds):
            return "\(tool) did not finish within \(Int(seconds)) s"
        }
    }
}
