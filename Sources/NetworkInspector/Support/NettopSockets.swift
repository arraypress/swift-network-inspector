//
//  NettopSockets.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  One sample of `nettop -L 1 -n -x -J state` as sockets. nettop writes a
//  row per process (`remoted.569,,`) followed by a row per socket it holds
//  (`tcp6 fe80::1%anri0.49935<->*.*,Listen,`). IPv4 joins address and
//  port with a colon (`*:49188`, `127.0.0.1:17600`), IPv6 with a dot
//  (`*.49188`), and states are written `Listen`, `Established`,
//  `FinWait1` — read here as netstat's `LISTEN`, `FIN_WAIT_1`.
//
//  nettop reads the kernel's network statistics, which an ordinary user
//  may read for every process, so root's sockets are here with their pid.
//  It lists the sockets it has statistics for: on the Mac this was built
//  on, all 13 TCP listeners netstat showed, but 15 of 19 UDP listeners —
//  the four it missed were idle sockets of one process.
//

import Foundation

enum NettopSockets {

    /// The sockets in one sample.
    static func sockets(header: String, lines: [String]) -> [SocketEntry] {
        let names = header.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard let nameColumn = names.firstIndex(of: "") else { return [] }
        let stateColumn = names.firstIndex(of: "state")
        var owner: (name: String, pid: Int32)?
        var sockets: [SocketEntry] = []
        for line in lines {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            let extra = max(0, fields.count - names.count)
            guard nameColumn + extra < fields.count else { continue }
            let label = fields[nameColumn...(nameColumn + extra)].joined(separator: ",")
            if let socket = socket(label, owner: owner) {
                let state = stateColumn.map { $0 > nameColumn ? $0 + extra : $0 }
                    .flatMap { $0 < fields.count ? String(fields[$0]) : nil }
                sockets.append(SocketEntry(proto: socket.proto, family: socket.family, local: socket.local,
                                           remote: socket.remote,
                                           state: socket.proto == .tcp ? state.flatMap(Self.state) : nil,
                                           pid: socket.pid, processName: socket.processName))
            } else if let (name, pid) = NettopCSV.namePID(label) {
                owner = (name, pid)
            }
        }
        return sockets
    }

    /// `tcp4 127.0.0.1:17600<->*:*` as a socket owned by `owner`; nil for a process row.
    static func socket(_ label: String, owner: (name: String, pid: Int32)?) -> SocketEntry? {
        guard let match = label.wholeMatch(of: /(tcp|udp)(46|4|6) (\S+)<->(\S+)/) else { return nil }
        let family = String(match.2)
        guard let local = endpoint(match.3, family: family), let remote = endpoint(match.4, family: family) else {
            return nil
        }
        return SocketEntry(proto: match.1 == "tcp" ? .tcp : .udp, family: family, local: local,
                           remote: remote.address == "*" && remote.port == nil ? nil : remote,
                           state: nil, pid: owner?.pid, processName: owner?.name)
    }

    /// An endpoint in nettop's two forms: `a.b.c.d:port` for IPv4, `addr.port`
    /// for IPv6 and dual-stack.
    static func endpoint(_ text: Substring, family: String) -> Endpoint? {
        family == "4" ? EndpointText.lsof(text) : EndpointText.netstat(text)
    }

    /// `FinWait1` → `FIN_WAIT_1`; empty → nil.
    static func state(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        var out = ""
        for character in text {
            if (character.isUppercase || character.isNumber), !out.isEmpty, out.last != "_" { out.append("_") }
            out.append(character)
        }
        return out.uppercased()
    }
}
