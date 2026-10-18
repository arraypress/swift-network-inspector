//
//  EndpointText.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  The two ways the tools write an address and port. netstat joins them
//  with a dot — `127.0.0.1.17603`, `fe80::1%en0.49936`, `*.5353`, `*.*` —
//  so the port is after the LAST dot. lsof uses a colon and brackets IPv6:
//  `127.0.0.1:17600`, `[::1]:8080`, `*:5353`, `*:*`.
//

import Foundation

enum EndpointText {

    /// netstat's `address.port`.
    static func netstat(_ text: Substring) -> Endpoint? {
        guard let dot = text.lastIndex(of: ".") else { return nil }
        let address = String(text[..<dot])
        let portText = text[text.index(after: dot)...]
        guard !address.isEmpty else { return nil }
        if portText == "*" { return Endpoint(address: address, port: nil) }
        guard let port = Int(portText) else { return nil }
        return Endpoint(address: address, port: port)
    }

    /// lsof's `address:port`, with IPv6 in brackets.
    static func lsof(_ text: Substring) -> Endpoint? {
        var address: Substring
        var portText: Substring
        if text.hasPrefix("[") {
            guard let close = text.firstIndex(of: "]") else { return nil }
            address = text[text.index(after: text.startIndex)..<close]
            let rest = text[text.index(after: close)...]
            guard rest.hasPrefix(":") else { return nil }
            portText = rest.dropFirst()
        } else {
            guard let colon = text.lastIndex(of: ":") else { return nil }
            address = text[..<colon]
            portText = text[text.index(after: colon)...]
        }
        guard !address.isEmpty else { return nil }
        if portText == "*" { return Endpoint(address: String(address), port: nil) }
        guard let port = Int(portText) else { return nil }
        return Endpoint(address: String(address), port: port)
    }
}
