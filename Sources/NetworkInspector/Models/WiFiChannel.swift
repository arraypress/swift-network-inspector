//
//  WiFiChannel.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A Wi-Fi channel: its number (the primary 20 MHz channel, as CoreWLAN
/// gives it), its band and its width.
public struct WiFiChannel: Codable, Sendable, Equatable, Hashable {

    /// The primary channel number.
    public let number: Int

    /// The band.
    public let band: WiFiBand

    /// The width in MHz (20, 40, 80, 160), nil when unknown.
    public let widthMHz: Int?

    public init(number: Int, band: WiFiBand, widthMHz: Int?) {
        self.number = number
        self.band = band
        self.widthMHz = widthMHz
    }
}
