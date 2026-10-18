//
//  SocketProtocol.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The transport a socket speaks.
public enum SocketProtocol: String, Codable, Sendable, CaseIterable {
    case tcp
    case udp
}
