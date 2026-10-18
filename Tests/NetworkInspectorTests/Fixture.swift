//
//  Fixture.swift
//  NetworkInspectorTests
//
//  Created by David Sherlock on 2026.
//
//  The captured outputs in Fixtures/: nettop, netstat, lsof and
//  networkQuality as they ran on a Mac (macOS 27.0.1, 2026-10-18), with
//  every address replaced by a documentation value — IPv4 by 192.0.2.x,
//  198.51.100.x and 203.0.113.x, global IPv6 by 2001:db8::n, link-local
//  interface ids by fe80::n — and the login name by `me`. Loopback
//  addresses, ports, pids and process names are as captured.
//

import Foundation
@testable import NetworkInspector

enum Fixture {

    static func data(_ name: String) throws -> Data {
        let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
        guard let url = Bundle.module.url(forResource: base, withExtension: ext, subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: name])
        }
        return try Data(contentsOf: url)
    }

    static func text(_ name: String) throws -> String { String(decoding: try data(name), as: UTF8.self) }

    /// An identity with no lookup, for the pure arithmetic.
    static func identity(_ row: NettopRow) -> ProcessIdentity { ProcessIdentity(pid: row.pid, name: row.name) }
}
