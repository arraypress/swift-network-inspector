//
//  ChannelLoad.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How many scanned networks share air with one channel.
public struct ChannelLoad: Codable, Sendable, Equatable {

    /// The band.
    public let band: WiFiBand

    /// The channel number.
    public let channel: Int

    /// Networks whose channel overlaps this one.
    public let networks: Int

    /// Of those, the ones heard at -70 dBm or stronger — loud enough to
    /// take turns with.
    public let strong: Int

    public init(band: WiFiBand, channel: Int, networks: Int, strong: Int) {
        self.band = band
        self.channel = channel
        self.networks = networks
        self.strong = strong
    }
}
