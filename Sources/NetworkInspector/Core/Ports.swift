//
//  Ports.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  What is listening, and for whom — without root. Three sources, in order:
//
//  1. `netstat -anvl`: the kernel's socket tables with a pid per socket,
//     every user's. From a shell it lists everything. But on macOS 27.0.1
//     it lists NO Internet sockets — exit 0, only Unix-domain sockets —
//     whenever a non-Apple program is among its ancestors (measured: run
//     from Python, from a Swift binary, and from /bin/sh started by
//     either; the same with the agent sandbox off). That is every way this
//     library runs it, so it is used only when it does answer.
//  2. nettop's per-socket listing, which an ordinary user may read for
//     every process and which answers from here: root's `remoted`
//     listeners included. It skips sockets it has no statistics for (4 idle
//     UDP sockets of 19, measured), so lsof's list for the caller's own
//     processes is merged in.
//  3. lsof alone: only the caller's own processes. The report then counts
//     the other users' processes whose sockets went unseen.
//

import Darwin
import Foundation

public enum Ports {

    /// The ports in use.
    ///
    /// - Parameters:
    ///   - includeConnected: Also list connected sockets, not only what listens.
    ///   - port: Only this local port.
    /// - Throws: ``NetworkInspectorError`` when no source gives a list.
    public static func report(includeConnected: Bool = false, port: Int? = nil) throws -> PortReport {
        let list = try sockets()
        let addresses = Interfaces.byAddress(Interfaces.addresses())
        let rows = PortMerge.rows(list.sockets, includeConnected: includeConnected, port: port, addresses: addresses) {
            ProcessLookup.identity(pid: $0, fallbackName: $1)
        }
        return PortReport(ports: rows, source: list.source, complete: list.complete,
                          hiddenProcesses: list.hiddenProcesses,
                          unnamed: rows.filter { $0.process?.path == nil }.count, notes: list.notes)
    }

    /// Every TCP and UDP socket that can be seen.
    ///
    /// - Throws: ``NetworkInspectorError`` when no source gives a list.
    public static func sockets() throws -> SocketList {
        if let found = netstat(), found.contains(where: { $0.local.port != nil }) {
            return SocketList(sockets: found, source: .netstat, complete: true, hiddenProcesses: nil, notes: [])
        }
        var notes: [String] = []
        var found: [SocketEntry]?
        do { found = try nettop() } catch { notes.append("nettop gave no socket list: \(error.localizedDescription)") }
        let own = (try? lsof()) ?? []
        if let found {
            notes.append("idle UDP sockets of other users' processes can be missing: nettop lists the sockets it has statistics for")
            return SocketList(sockets: merged(found, own), source: .nettop, complete: true, hiddenProcesses: nil,
                              notes: notes)
        }
        guard !own.isEmpty else {
            throw NetworkInspectorError.toolFailed(tool: "nettop and lsof", reason: "neither listed any socket")
        }
        let hidden = ProcessLookup.otherUsersProcessCount()
        notes.append("only this user's processes are visible without root"
                     + (hidden.map { "; \($0) processes of other users, root's included, were not looked at" } ?? ""))
        return SocketList(sockets: own, source: .lsof, complete: false, hiddenProcesses: hidden, notes: notes)
    }

    /// `netstat -anvl` for TCP and UDP; nil when either is not in the expected shape.
    static func netstat() -> [SocketEntry]? {
        guard let tcp = try? ToolRunner.run("/usr/sbin/netstat", ["-anvl", "-p", "tcp"], timeout: 20), tcp.status == 0,
              let udp = try? ToolRunner.run("/usr/sbin/netstat", ["-anvl", "-p", "udp"], timeout: 20), udp.status == 0,
              let tcpSockets = NetstatText.sockets(tcp.text), let udpSockets = NetstatText.sockets(udp.text) else {
            return nil
        }
        return tcpSockets + udpSockets
    }

    /// One sample of nettop's per-socket listing.
    static func nettop() throws -> [SocketEntry] {
        var sockets: [SocketEntry]?
        try NettopStream.run(["-L", "1", "-n", "-x", "-J", "state"], timeout: 15) { block in
            sockets = NettopSockets.sockets(header: block.header, lines: block.lines)
            return false
        }
        guard let sockets, !sockets.isEmpty else {
            throw NetworkInspectorError.toolFailed(tool: "nettop", reason: "it listed no sockets")
        }
        return sockets
    }

    /// `lsof -nP -iTCP -iUDP`: the caller's own sockets without root.
    static func lsof() throws -> [SocketEntry] {
        let output = try ToolRunner.run("/usr/sbin/lsof", ["-nP", "-iTCP", "-iUDP"], timeout: 30)
        // lsof exits 1 when some processes could not be read, with a usable list.
        guard !output.stdout.isEmpty else {
            throw NetworkInspectorError.toolFailed(tool: "lsof", reason: output.errorText.isEmpty ? "no output" : output.errorText)
        }
        return LsofText.sockets(output.text)
    }

    /// `base` plus every socket in `extra` it does not already hold — the
    /// same protocol, ends and pid. The family is left out of the match:
    /// nettop and lsof name a dual-stack socket differently.
    static func merged(_ base: [SocketEntry], _ extra: [SocketEntry]) -> [SocketEntry] {
        struct Key: Hashable { let proto: SocketProtocol, local: Endpoint, remote: Endpoint?, pid: Int32? }
        func key(_ socket: SocketEntry) -> Key {
            Key(proto: socket.proto, local: socket.local, remote: socket.remote, pid: socket.pid)
        }
        var seen = Set(base.map(key))
        var out = base
        for socket in extra where seen.insert(key(socket)).inserted { out.append(socket) }
        return out
    }
}
