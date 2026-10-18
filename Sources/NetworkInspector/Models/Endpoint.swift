//
//  Endpoint.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One end of a socket: an address and a port.
public struct Endpoint: Codable, Sendable, Equatable, Hashable {

    /// The numeric address, `*` for the wildcard. An IPv6 link-local
    /// address keeps its zone, e.g. `fe80::1%en0`.
    public let address: String

    /// The port; nil for an unbound or unconnected end (`*.*`).
    public let port: Int?

    public init(address: String, port: Int?) {
        self.address = address
        self.port = port
    }

    /// Whether this is the wildcard address.
    public var isWildcard: Bool { address == "*" || address == "0.0.0.0" || address == "::" }
}
