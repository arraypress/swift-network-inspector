//
//  ReachRules.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  Who can reach a socket, from the address it is bound to. This is the
//  socket's own limit; the application firewall can refuse on top of it.
//

import Foundation

enum ReachRules {

    /// The reach of a bound address.
    static func reach(of address: String) -> Reach {
        let bare = address.split(separator: "%").first.map(String.init) ?? address
        if bare == "*" || bare == "0.0.0.0" || bare == "::" { return .all }
        if bare.hasPrefix("127.") || bare == "::1" || bare.lowercased().hasPrefix("::ffff:127.") { return .loopback }
        if bare.lowercased().hasPrefix("fe80:") || bare.hasPrefix("169.254.") { return .linkLocal }
        return .address
    }

    /// The interface a bound address belongs to: its zone (`fe80::1%en0`)
    /// when it has one, else the interface holding that address.
    static func interface(of address: String, addresses: [String: String]) -> String? {
        if let percent = address.firstIndex(of: "%") { return String(address[address.index(after: percent)...]) }
        return addresses[address]
    }
}
