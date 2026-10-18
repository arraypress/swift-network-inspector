//
//  ResponsivenessRating+Score.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

public extension ResponsivenessRating {

    /// networkQuality's rating for a score in round trips per minute:
    /// low up to 200, medium to 1,000, high above (measured; see
    /// ResponsivenessRules).
    init(rpm: Double) { self = ResponsivenessRules.rating(rpm) }
}
