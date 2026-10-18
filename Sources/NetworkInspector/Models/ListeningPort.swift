//
//  ListeningPort.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  A port something is waiting on, with the sockets behind it merged: the
//  IPv4 and IPv6 listeners one server opens for the same port are one row,
//  and so are the five mDNS sockets one process holds on 5353.
//

import Foundation

/// A port something listens on, and who.
public struct ListeningPort: Codable, Sendable, Equatable {

    /// TCP or UDP.
    public let proto: SocketProtocol

    /// The port number.
    public let port: Int

    /// The bound address: `*`, `127.0.0.1`, `::1`, `fe80::1%en0`, …
    public let address: String

    /// Who can connect, by that address.
    public let reach: Reach

    /// The interface a specific or link-local address belongs to.
    public let interface: String?

    /// The address families merged into this row: `4`, `6`, `46`.
    public let families: [String]

    /// How many sockets were merged into this row.
    public let sockets: Int

    /// The TCP state for rows from `--all` (`ESTABLISHED`…); `LISTEN` or nil otherwise.
    public let state: String?

    /// The remote end, for a connected socket listed by `--all`.
    public let remote: Endpoint?

    /// The owning process, when the socket list named one.
    public let process: ProcessIdentity?

    public init(proto: SocketProtocol, port: Int, address: String, reach: Reach, interface: String?,
                families: [String], sockets: Int, state: String?, remote: Endpoint?, process: ProcessIdentity?) {
        self.proto = proto
        self.port = port
        self.address = address
        self.reach = reach
        self.interface = interface
        self.families = families
        self.sockets = sockets
        self.state = state
        self.remote = remote
        self.process = process
    }
}
