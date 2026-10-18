//
//  RouteInfo.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The way out: the primary interface, its router, the DNS servers in use,
/// and any tunnel (VPN) interface that carries an address.
public struct RouteInfo: Codable, Sendable, Equatable {

    /// The interface macOS calls primary for IPv4, e.g. `en0`.
    public let primaryInterface: String?

    /// Its router.
    public let router: String?

    /// The resolvers in use, in order.
    public let dnsServers: [String]

    /// Tunnel interfaces (`utun`, `ipsec`, `ppp`) with a routable IPv4
    /// address — a VPN, almost always.
    public let tunnels: [String]

    public init(primaryInterface: String?, router: String?, dnsServers: [String], tunnels: [String]) {
        self.primaryInterface = primaryInterface
        self.router = router
        self.dnsServers = dnsServers
        self.tunnels = tunnels
    }
}
