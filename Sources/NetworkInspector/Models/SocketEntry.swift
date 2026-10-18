//
//  SocketEntry.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One socket, as netstat or lsof reported it.
public struct SocketEntry: Codable, Sendable, Equatable {

    /// TCP or UDP.
    public let proto: SocketProtocol

    /// `4`, `6`, or `46` for a dual-stack socket.
    public let family: String

    /// The local end.
    public let local: Endpoint

    /// The remote end; nil when not connected.
    public let remote: Endpoint?

    /// The TCP state (`LISTEN`, `ESTABLISHED`…); nil for UDP.
    public let state: String?

    /// The process that last used it, when known.
    public let pid: Int32?

    /// That process's name as the tool printed it — cut to 15 or 16
    /// characters, and possibly containing spaces or dots.
    public let processName: String?

    public init(proto: SocketProtocol, family: String, local: Endpoint, remote: Endpoint?, state: String?,
                pid: Int32?, processName: String?) {
        self.proto = proto
        self.family = family
        self.local = local
        self.remote = remote
        self.state = state
        self.pid = pid
        self.processName = processName
    }

    /// Whether it waits for others: a TCP listener, or a UDP socket bound to
    /// a port with no remote end.
    public var isListening: Bool {
        switch proto {
        case .tcp: return state == "LISTEN"
        case .udp: return local.port != nil && remote == nil
        }
    }
}
