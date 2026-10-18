//
//  PortReport.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The ports in use, with how complete the list is.
public struct PortReport: Codable, Sendable, Equatable {

    /// The ports, by port number then protocol.
    public let ports: [ListeningPort]

    /// Where the socket list came from.
    public let source: SocketSource

    /// Whether every user's listening sockets were visible: true from
    /// netstat and nettop; from lsof alone without root only the caller's
    /// own processes are.
    public let complete: Bool

    /// When only lsof answered: how many running processes belong to other
    /// users (root included) — their sockets could not be seen.
    public let hiddenProcesses: Int?

    /// Rows whose owning process could not be named (it exited, or the
    /// socket list gave no pid).
    public let unnamed: Int

    /// What limits the list, in words.
    public let notes: [String]

    public init(ports: [ListeningPort], source: SocketSource, complete: Bool, hiddenProcesses: Int?, unnamed: Int,
                notes: [String]) {
        self.ports = ports
        self.source = source
        self.complete = complete
        self.hiddenProcesses = hiddenProcesses
        self.unnamed = unnamed
        self.notes = notes
    }
}
