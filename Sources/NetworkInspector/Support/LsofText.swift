//
//  LsofText.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  `lsof -nP -iTCP -iUDP` as sockets — the fallback when netstat's output
//  is not in the shape NetstatText reads. Without root lsof lists only the
//  caller's own processes; the result says so (`PortReport.complete`).
//  lsof escapes a space in a command name as `\x20`, so the columns before
//  NAME split on whitespace; NAME is `local`, `local->remote`, then the TCP
//  state in parentheses.
//

import Foundation

enum LsofText {

    /// The sockets in one lsof listing.
    static func sockets(_ text: String) -> [SocketEntry] {
        text.split(whereSeparator: \.isNewline).compactMap(socket)
    }

    /// One row; nil for the header or anything that is not a TCP/UDP socket.
    static func socket(_ line: Substring) -> SocketEntry? {
        let fields = line.split(whereSeparator: \.isWhitespace)
        guard fields.count >= 9, let pid = Int32(fields[1]),
              let node = fields.indices.dropFirst(4).first(where: { fields[$0] == "TCP" || fields[$0] == "UDP" }),
              node + 1 < fields.count else { return nil }
        let proto: SocketProtocol = fields[node] == "TCP" ? .tcp : .udp
        let family = fields[4] == "IPv6" ? "6" : "4"
        let name = fields[node + 1]
        let ends = name.components(separatedBy: "->")
        guard let local = EndpointText.lsof(Substring(ends[0])) else { return nil }
        let remote = ends.count > 1 ? EndpointText.lsof(Substring(ends[1])) : nil
        var state: String?
        if node + 2 < fields.count, fields[node + 2].hasPrefix("(") {
            state = String(fields[node + 2].dropFirst().dropLast())
        }
        return SocketEntry(proto: proto, family: family, local: local, remote: remote,
                           state: proto == .tcp ? state : nil, pid: pid, processName: command(fields[0]))
    }

    /// The command name with lsof's `\x20` escapes undone.
    static func command(_ field: Substring) -> String {
        field.replacingOccurrences(of: "\\x20", with: " ")
    }
}
