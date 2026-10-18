//
//  PortMerge.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  Sockets into rows. A server usually opens one listener per address
//  family on the same port, and mDNS clients hold several sockets on 5353;
//  each of those is one row, with the families and the socket count kept.
//  Connected sockets (`--all`) stay one row each.
//

import Foundation

enum PortMerge {

    /// The rows for a socket list.
    ///
    /// - Parameters:
    ///   - sockets: Every socket.
    ///   - includeConnected: Keep connected sockets and non-listening TCP states too.
    ///   - port: Only this local port, when given.
    ///   - addresses: Interface addresses (`192.0.2.4` → `en0`).
    ///   - identify: Names a pid; netstat's cut name comes along as the fallback.
    static func rows(_ sockets: [SocketEntry], includeConnected: Bool, port: Int?, addresses: [String: String],
                     identify: (Int32, String?) -> ProcessIdentity?) -> [ListeningPort] {
        struct Key: Hashable {
            let proto: SocketProtocol, port: Int, address: String, pid: Int32?, state: String?, remote: Endpoint?
        }
        var order: [Key] = []
        var grouped: [Key: [SocketEntry]] = [:]
        for socket in sockets {
            guard let localPort = socket.local.port else { continue }
            if let port, localPort != port { continue }
            let listening = socket.isListening
            guard listening || includeConnected else { continue }
            let address = socket.local.isWildcard ? "*" : socket.local.address
            let key = Key(proto: socket.proto, port: localPort, address: address, pid: socket.pid,
                          state: socket.state, remote: listening ? nil : socket.remote)
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(socket)
        }
        var names: [Int32: ProcessIdentity?] = [:]
        let rows = order.map { key -> ListeningPort in
            let members = grouped[key] ?? []
            let process = key.pid.flatMap { pid -> ProcessIdentity? in
                if let known = names[pid] { return known }
                let found = identify(pid, members.first?.processName)
                names[pid] = found
                return found
            }
            let families = Array(Set(members.map(\.family))).sorted()
            return ListeningPort(proto: key.proto, port: key.port, address: key.address,
                                 reach: ReachRules.reach(of: key.address),
                                 interface: ReachRules.interface(of: key.address, addresses: addresses),
                                 families: families, sockets: members.count, state: key.state, remote: key.remote,
                                 process: process)
        }
        return rows.sorted { a, b in
            if a.port != b.port { return a.port < b.port }
            if a.proto != b.proto { return a.proto.rawValue < b.proto.rawValue }
            if a.address != b.address { return a.address < b.address }
            return (a.process?.pid ?? 0) < (b.process?.pid ?? 0)
        }
    }
}
