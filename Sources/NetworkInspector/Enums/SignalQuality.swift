//
//  SignalQuality.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A plain-words verdict on a Wi-Fi link, from its signal and noise.
public enum SignalQuality: String, Codable, Sendable, CaseIterable {
    case excellent
    case good
    case fair
    case poor
}
