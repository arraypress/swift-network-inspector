//
//  Reach.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  Who can connect to a listening socket, by the address it is bound to —
//  the thing that matters for exposure. The application firewall may still
//  refuse a connection; reach is what the socket itself allows.
//

import Foundation

/// How far a listening socket can be reached from.
public enum Reach: String, Codable, Sendable, CaseIterable {

    /// 127.0.0.0/8 or ::1: this Mac only.
    case loopback

    /// fe80::/10 or 169.254.0.0/16: machines on the same link only.
    case linkLocal = "link-local"

    /// One specific address: whoever can reach that interface's network.
    case address

    /// The wildcard (`*`, 0.0.0.0, ::): every interface, present and future.
    case all

    /// Whether anything other than this Mac can connect.
    public var isExposed: Bool { self != .loopback }
}
