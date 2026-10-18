//
//  WiFiScan.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The networks a scan heard, strongest first, and what they mean for the
/// channel in use.
public struct WiFiScan: Codable, Sendable, Equatable {

    /// The networks, strongest first.
    public let networks: [NearbyNetwork]

    /// Channel crowding, and advice.
    public let advice: ChannelAdvice

    /// Whether names were withheld (Location Services).
    public let namesWithheld: Bool

    /// How long the scan took, seconds.
    public let seconds: Double

    public init(networks: [NearbyNetwork], advice: ChannelAdvice, namesWithheld: Bool, seconds: Double) {
        self.networks = networks
        self.advice = advice
        self.namesWithheld = namesWithheld
        self.seconds = seconds
    }
}
