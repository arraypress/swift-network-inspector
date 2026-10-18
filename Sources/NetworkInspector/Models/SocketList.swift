//
//  SocketList.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Every socket that could be seen, and how complete that is.
public struct SocketList: Codable, Sendable, Equatable {

    /// The sockets.
    public let sockets: [SocketEntry]

    /// Where they came from.
    public let source: SocketSource

    /// Whether every user's listening sockets were visible.
    public let complete: Bool

    /// When only lsof answered: other users' running processes, unseen.
    public let hiddenProcesses: Int?

    /// What limits the list, in words.
    public let notes: [String]

    public init(sockets: [SocketEntry], source: SocketSource, complete: Bool, hiddenProcesses: Int?, notes: [String]) {
        self.sockets = sockets
        self.source = source
        self.complete = complete
        self.hiddenProcesses = hiddenProcesses
        self.notes = notes
    }
}
