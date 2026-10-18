//
//  WiFiStatus.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  The Wi-Fi link right now. Recent macOS withholds the network's name,
//  its BSSID and the country code unless Location Services allows the app
//  running this; they are then nil, and `locationWithheld` says why.
//  Everything else — signal, noise, channel, rate, security — comes back
//  without any permission. CoreWLAN's transmit power is left out: it read
//  1496 on a MacBook, which as the milliwatts its header promises would be
//  1.5 W, so its unit cannot be trusted.
//

import Foundation

/// The Wi-Fi interface and the link it holds.
public struct WiFiStatus: Codable, Sendable, Equatable {

    /// The BSD name, e.g. `en0`.
    public let interface: String

    /// Whether the radio is on.
    public let powerOn: Bool

    /// Whether it is associated with a network.
    public let connected: Bool

    /// The network's name; nil when withheld or not connected.
    public let ssid: String?

    /// The access point's BSSID; nil when withheld or not connected.
    public let bssid: String?

    /// Received signal strength, dBm.
    public let rssi: Int?

    /// Noise floor, dBm.
    public let noise: Int?

    /// Signal minus noise, dB.
    public let snr: Int?

    /// The channel in use.
    public let channel: WiFiChannel?

    /// The 802.11 mode, e.g. `802.11ax`.
    public let phyMode: String?

    /// The Wi-Fi generation name, e.g. `Wi-Fi 6`.
    public let generation: String?

    /// The current transmit rate, Mbps.
    public let transmitRate: Double?

    /// The security in use, e.g. `WPA2 Personal`.
    public let security: String?

    /// The country code the radio is set for; withheld like the SSID.
    public let countryCode: String?

    /// A verdict from signal and noise.
    public let quality: SignalQuality?

    /// Whether the SSID came back nil while connected — Location Services
    /// is not allowed for the app running this.
    public let locationWithheld: Bool

    public init(interface: String, powerOn: Bool, connected: Bool, ssid: String?, bssid: String?, rssi: Int?,
                noise: Int?, snr: Int?, channel: WiFiChannel?, phyMode: String?, generation: String?,
                transmitRate: Double?, security: String?, countryCode: String?,
                quality: SignalQuality?, locationWithheld: Bool) {
        self.interface = interface
        self.powerOn = powerOn
        self.connected = connected
        self.ssid = ssid
        self.bssid = bssid
        self.rssi = rssi
        self.noise = noise
        self.snr = snr
        self.channel = channel
        self.phyMode = phyMode
        self.generation = generation
        self.transmitRate = transmitRate
        self.security = security
        self.countryCode = countryCode
        self.quality = quality
        self.locationWithheld = locationWithheld
    }
}
