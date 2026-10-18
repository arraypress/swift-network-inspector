//
//  NearbyNetwork.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One network a scan heard.
public struct NearbyNetwork: Codable, Sendable, Equatable {

    /// Its name; nil when Location Services withholds it (or it hides it).
    public let ssid: String?

    /// Its BSSID; nil when withheld.
    public let bssid: String?

    /// Signal strength here, dBm.
    public let rssi: Int

    /// The channel it beacons on.
    public let channel: WiFiChannel

    /// The strongest security it offers, e.g. `WPA3 Personal`; nil when unknown.
    public let security: String?

    public init(ssid: String?, bssid: String?, rssi: Int, channel: WiFiChannel, security: String?) {
        self.ssid = ssid
        self.bssid = bssid
        self.rssi = rssi
        self.channel = channel
        self.security = security
    }
}
