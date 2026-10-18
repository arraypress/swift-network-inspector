//
//  WiFi.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  The Wi-Fi link and a scan of what is nearby, through CoreWLAN — not the
//  `airport` tool, which is gone, nor `wdutil`, which needs sudo.
//
//  Measured on macOS 27 from a command-line tool whose terminal has no
//  Location Services permission: signal, noise, channel, band, width, PHY
//  mode, transmit rate and security all come back; the SSID,
//  BSSID and country code come back nil. A scan works too — 7 networks
//  in 4.8 s, with channels and signal but no names. This library never
//  asks for the permission: a command-line tool cannot show the prompt
//  itself, and asking would only fail quietly.
//

import CoreWLAN
import Foundation

public enum WiFi {

    /// The Wi-Fi interface and its link.
    ///
    /// - Throws: ``NetworkInspectorError/noWiFi``.
    public static func status() throws -> WiFiStatus {
        guard let interface = CWWiFiClient.shared().interface() else { throw NetworkInspectorError.noWiFi }
        return read(interface)
    }

    /// The networks within range, and what they mean for the channel in use.
    /// Takes a few seconds.
    ///
    /// - Throws: ``NetworkInspectorError/noWiFi``, ``NetworkInspectorError/scanFailed(_:)``.
    public static func scan() throws -> WiFiScan {
        guard let interface = CWWiFiClient.shared().interface() else { throw NetworkInspectorError.noWiFi }
        guard interface.powerOn() else { throw NetworkInspectorError.scanFailed("Wi-Fi is turned off") }
        let started = Date()
        let found: Set<CWNetwork>
        do { found = try interface.scanForNetworks(withName: nil) } catch {
            throw NetworkInspectorError.scanFailed(error.localizedDescription)
        }
        let networks = found.compactMap(nearby).sorted { $0.rssi > $1.rssi }
        let current = read(interface)
        return WiFiScan(networks: networks,
                        advice: ChannelRules.advice(networks: networks, current: current.connected ? current.channel : nil),
                        namesWithheld: !networks.isEmpty && networks.allSatisfy { $0.ssid == nil && $0.bssid == nil },
                        seconds: Date().timeIntervalSince(started))
    }

    /// One interface's state as a value.
    static func read(_ interface: CWInterface) -> WiFiStatus {
        let channel = interface.wlanChannel().map(channel)
        let connected = channel != nil && interface.rssiValue() != 0
        let rssi = connected ? interface.rssiValue() : nil
        let noise = connected ? interface.noiseMeasurement() : nil
        let ssid = interface.ssid()
        let phy = interface.activePHYMode().rawValue
        let transmitRate = interface.transmitRate()
        return WiFiStatus(
            interface: interface.interfaceName ?? "en0",
            powerOn: interface.powerOn(),
            connected: connected,
            ssid: ssid,
            bssid: interface.bssid(),
            rssi: rssi,
            noise: noise,
            snr: rssi.flatMap { SignalRules.snr(rssi: $0, noise: noise) },
            channel: channel,
            phyMode: connected ? WiFiNames.phyMode(phy) : nil,
            generation: connected ? WiFiNames.generation(phy, band: channel?.band) : nil,
            transmitRate: connected && transmitRate > 0 ? transmitRate : nil,
            security: connected ? WiFiNames.security(interface.security().rawValue) : nil,
            countryCode: interface.countryCode(),
            quality: rssi.map { SignalRules.quality(rssi: $0, noise: noise) },
            locationWithheld: connected && ssid == nil)
    }

    /// A scanned network as a value; nil when it has no channel.
    static func nearby(_ network: CWNetwork) -> NearbyNetwork? {
        guard let channel = network.wlanChannel.map(channel) else { return nil }
        let security = WiFiNames.strongestFirst.first { raw in
            CWSecurity(rawValue: raw).map(network.supportsSecurity) ?? false
        }
        return NearbyNetwork(ssid: network.ssid, bssid: network.bssid, rssi: network.rssiValue, channel: channel,
                             security: security.flatMap(WiFiNames.security))
    }

    static func channel(_ channel: CWChannel) -> WiFiChannel {
        WiFiChannel(number: channel.channelNumber, band: WiFiNames.band(channel.channelBand.rawValue),
                    widthMHz: WiFiNames.width(channel.channelWidth.rawValue))
    }
}
