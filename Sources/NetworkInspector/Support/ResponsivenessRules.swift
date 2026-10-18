//
//  ResponsivenessRules.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  networkQuality's own thresholds, measured rather than looked up: its
//  rating comes from `+[NetworkQualityResult ratingForResponsivenessScore:]`
//  in the private NetworkQuality framework, which takes whole round trips
//  per minute. Called for every score from 0 to 5,000 on macOS 27.0.1, it
//  answered Low up to 200, Medium from 201 to 1,000 and High from 1,001.
//

import Foundation

enum ResponsivenessRules {

    /// The rating for a score; fractions are dropped, as the framework's
    /// integer argument drops them.
    static func rating(_ rpm: Double) -> ResponsivenessRating {
        let whole = Int(rpm)
        return whole <= 200 ? .low : whole <= 1000 ? .medium : .high
    }
}
