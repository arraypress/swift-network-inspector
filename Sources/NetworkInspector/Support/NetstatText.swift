//
//  NetstatText.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  `netstat -anvl -p tcp` (or `-p udp`) as sockets. netstat reads the
//  kernel's socket tables, which any user may read, and `-v` adds a
//  `process:pid` column — so unlike lsof it sees root's and other users'
//  sockets without root (measured on macOS 27: the two listeners lsof
//  missed here were root's `remoted`). `-l` prints IPv6 addresses in full;
//  without it they are cut to fit (`fe80::1804:50ff:.49936`).
//
//  Columns are whitespace-separated except `process:pid`, which holds the
//  name netstat cut to 16 characters and that may contain spaces
//  (`Google Chrome He:2149`). The header says how many columns come before
//  and after it; UDP rows leave the state column empty, so a field that is
//  not a number there is the TCP state.
//

import Foundation

enum NetstatText {

    /// The sockets in one netstat listing, or nil when the header has no
    /// `process:pid` column (an older or newer netstat, or no `-v`).
    static func sockets(_ text: String) -> [SocketEntry]? {
        let lines = text.split(whereSeparator: \.isNewline)
        guard let header = lines.first(where: { $0.hasPrefix("Proto") }) else { return nil }
        let names = header.split(whereSeparator: \.isWhitespace)
        guard let process = names.firstIndex(of: "process:pid"), let state = names.firstIndex(of: "(state)") else {
            return nil
        }
        let between = process - state - 1   // rxbytes txbytes rhiwat shiwat
        let after = names.count - process - 1
        return lines.compactMap { socket($0, between: between, after: after) }
    }

    /// One row; nil for a header, a blank or anything not tcp/udp.
    static func socket(_ line: Substring, between: Int, after: Int) -> SocketEntry? {
        let fields = line.split(whereSeparator: \.isWhitespace)
        guard fields.count >= 5 else { return nil }
        let protoText = fields[0]
        let proto: SocketProtocol
        if protoText.hasPrefix("tcp") { proto = .tcp } else if protoText.hasPrefix("udp") { proto = .udp } else { return nil }
        guard let local = EndpointText.netstat(fields[3]), let foreign = EndpointText.netstat(fields[4]) else { return nil }
        var index = 5
        var state: String?
        if index < fields.count, Int(fields[index]) == nil {
            state = String(fields[index])
            index += 1
        }
        index += between
        let end = fields.count - after
        var pid: Int32?
        var name: String?
        if index < end {
            let label = fields[index..<end].joined(separator: " ")
            // A socket whose process has exited keeps its pid and loses its
            // name: `:71051`.
            if let colon = label.lastIndex(of: ":"), let number = Int32(label[label.index(after: colon)...]) {
                pid = number
                name = colon == label.startIndex ? nil : String(label[..<colon])
            }
        }
        let remote: Endpoint? = foreign.address == "*" && foreign.port == nil ? nil : foreign
        return SocketEntry(proto: proto, family: String(protoText.dropFirst(3)), local: local, remote: remote,
                           state: proto == .tcp ? state : nil, pid: pid, processName: name)
    }
}
