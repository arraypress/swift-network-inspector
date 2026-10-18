//
//  FirewallState.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The macOS application firewall, as `socketfilterfw` reports it — readable
/// without root. Nil fields could not be read.
public struct FirewallState: Codable, Sendable, Equatable {

    /// Whether incoming connections are filtered at all.
    public let enabled: Bool?

    /// Whether the Mac ignores pings and closed-port probes.
    public let stealth: Bool?

    /// Whether every incoming connection is blocked, apps' included.
    public let blockAll: Bool?

    public init(enabled: Bool?, stealth: Bool?, blockAll: Bool?) {
        self.enabled = enabled
        self.stealth = stealth
        self.blockAll = blockAll
    }
}
