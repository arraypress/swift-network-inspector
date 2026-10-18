//
//  WiFiBand.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A Wi-Fi frequency band.
public enum WiFiBand: String, Codable, Sendable, CaseIterable {
    case ghz2 = "2.4 GHz"
    case ghz5 = "5 GHz"
    case ghz6 = "6 GHz"
    case unknown
}
