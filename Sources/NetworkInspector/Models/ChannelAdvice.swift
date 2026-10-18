//
//  ChannelAdvice.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a scan says about the channel in use.
public struct ChannelAdvice: Codable, Sendable, Equatable {

    /// The channel this Mac is on, when connected.
    public let current: WiFiChannel?

    /// Other networks overlapping it (the Mac's own access point excluded
    /// when it can be told apart: the strongest network on exactly the
    /// same channel).
    public let overlapping: Int

    /// Of those, the ones at -70 dBm or stronger.
    public let strongOverlapping: Int

    /// `crowded`, `busy` or `clear`.
    public let verdict: String

    /// One sentence for a person.
    public let advice: String

    /// The 2.4 GHz non-overlapping channels and the 5 GHz channels heard,
    /// with their load.
    public let loads: [ChannelLoad]

    public init(current: WiFiChannel?, overlapping: Int, strongOverlapping: Int, verdict: String, advice: String,
                loads: [ChannelLoad]) {
        self.current = current
        self.overlapping = overlapping
        self.strongOverlapping = strongOverlapping
        self.verdict = verdict
        self.advice = advice
        self.loads = loads
    }
}
