//
//  ResponsivenessRating.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// networkQuality's own words for a responsiveness score.
public enum ResponsivenessRating: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
}
