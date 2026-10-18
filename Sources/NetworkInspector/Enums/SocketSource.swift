//
//  SocketSource.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where a socket list came from, and so how complete it is.
public enum SocketSource: String, Codable, Sendable {

    /// `netstat -anvl`: the kernel's socket tables, every user's sockets with
    /// their pids. Used when it answers — which, on macOS 27, it does from
    /// a shell but not from a program like this one (see ``Ports``).
    case netstat

    /// `nettop`'s per-socket listing, joined with lsof's for the caller's
    /// own processes: every user's TCP sockets and every socket nettop has
    /// statistics for — idle UDP sockets of other users can be missing.
    case nettop

    /// `lsof -nP -i` alone: only the caller's own processes without root.
    case lsof
}
