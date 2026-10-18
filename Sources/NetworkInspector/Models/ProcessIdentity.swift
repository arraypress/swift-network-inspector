//
//  ProcessIdentity.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  Who a pid is: the full process name (nettop and netstat cut it to 15 or
//  16 characters), its executable, its user, and the app it belongs to —
//  the outermost .app around the executable, so a browser's helpers and an
//  app extension count as the app.
//

import Foundation

/// A process, named as fully as an unprivileged caller can.
public struct ProcessIdentity: Codable, Sendable, Equatable {

    /// The process identifier.
    public let pid: Int32

    /// The executable's file name, or the tool's own (possibly cut) name
    /// when the path cannot be read — e.g. the process has gone.
    public let name: String

    /// The executable's path, when readable.
    public let path: String?

    /// The owning user's login name.
    public let user: String?

    /// The owning user's id.
    public let uid: UInt32?

    /// The app the executable lives in, by its display name.
    public let appName: String?

    /// That app's bundle identifier.
    public let bundleIdentifier: String?

    /// That app's path.
    public let appPath: String?

    public init(pid: Int32, name: String, path: String? = nil, user: String? = nil, uid: UInt32? = nil,
                appName: String? = nil, bundleIdentifier: String? = nil, appPath: String? = nil) {
        self.pid = pid
        self.name = name
        self.path = path
        self.user = user
        self.uid = uid
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.appPath = appPath
    }

    /// What a person calls it: the app's name, else the process's.
    public var displayName: String { appName ?? name }
}
