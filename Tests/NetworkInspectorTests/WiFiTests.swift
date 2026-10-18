//
//  WiFiTests.swift
//  NetworkInspectorTests
//
//  Created by David Sherlock on 2026.
//
//  The signal verdict, which channels share air, and the advice a scan
//  gives. `measuredScan` is the scan CoreWLAN returned on the Mac this was
//  built on (2026-10-18, no Location Services: no names, no BSSIDs).
//

import Foundation
import Testing
@testable import NetworkInspector

struct WiFiTests {

    /// Channel, band, width and signal as scanned; the -54 dBm network on
    /// 153 is the Mac's own access point.
    let measuredScan: [NearbyNetwork] = [
        (153, WiFiBand.ghz5, 80, -54), (5, .ghz2, 20, -83), (11, .ghz2, 40, -49), (2, .ghz2, 20, -84),
        (36, .ghz5, 80, -84), (100, .ghz5, 20, -90), (128, .ghz5, 160, -91),
    ].map { NearbyNetwork(ssid: nil, bssid: nil, rssi: $0.3, channel: WiFiChannel(number: $0.0, band: $0.1, widthMHz: $0.2),
                          security: nil) }

    func channel(_ number: Int, _ band: WiFiBand, _ width: Int? = 20) -> WiFiChannel {
        WiFiChannel(number: number, band: band, widthMHz: width)
    }

    @Test func theVerdictIsTheWorseOfSignalAndNoise() {
        #expect(SignalRules.quality(rssi: -55, noise: -93) == .good, "-55 dBm, SNR 38 dB")
        #expect(SignalRules.quality(rssi: -58, noise: -95) == .good, "this Mac, as measured")
        #expect(SignalRules.quality(rssi: -45, noise: -95) == .excellent)
        #expect(SignalRules.quality(rssi: -72, noise: -95) == .fair)
        #expect(SignalRules.quality(rssi: -81, noise: -95) == .poor)
        #expect(SignalRules.quality(rssi: -45, noise: -60) == .fair, "a strong signal in loud noise is only fair")
        #expect(SignalRules.quality(rssi: -45, noise: 0) == .excellent, "noise 0 is CoreWLAN for not measured")
        #expect(SignalRules.snr(rssi: -58, noise: -95) == 37)
        #expect(SignalRules.snr(rssi: -58, noise: 0) == nil && SignalRules.snr(rssi: -58, noise: nil) == nil)
    }

    @Test func boundariesFallOnTheSideOfTheBetterVerdict() {
        #expect(SignalRules.quality(rssi: -50, noise: nil) == .excellent)
        #expect(SignalRules.quality(rssi: -67, noise: nil) == .good)
        #expect(SignalRules.quality(rssi: -68, noise: nil) == .fair)
        #expect(SignalRules.quality(rssi: -75, noise: nil) == .fair)
        #expect(SignalRules.quality(rssi: -76, noise: nil) == .poor)
        #expect(SignalRules.quality(rssi: -40, noise: -80) == .excellent, "SNR 40")
        #expect(SignalRules.quality(rssi: -40, noise: -79) == .good, "SNR 39")
        #expect(SignalRules.quality(rssi: -40, noise: -55) == .fair, "SNR 15")
        #expect(SignalRules.quality(rssi: -40, noise: -54) == .poor, "SNR 14")
    }

    @Test func twoPointFourGigahertzNeighboursOverlap() {
        #expect(!ChannelRules.overlaps(channel(1, .ghz2), channel(6, .ghz2)))
        #expect(!ChannelRules.overlaps(channel(6, .ghz2), channel(11, .ghz2)))
        #expect(ChannelRules.overlaps(channel(1, .ghz2), channel(5, .ghz2)), "within four channels")
        #expect(ChannelRules.overlaps(channel(11, .ghz2, 40), channel(6, .ghz2)), "a 40 MHz network spans either side")
        #expect(ChannelRules.span(channel(14, .ghz2)) == 2473...2495, "channel 14 sits apart, at 2484 MHz")
    }

    @Test func wideFiveGigahertzChannelsAreFixedBlocks() {
        #expect(ChannelRules.span(channel(153, .ghz5, 80)) == 5735...5815, "149–161")
        #expect(ChannelRules.span(channel(149, .ghz5, 80)) == ChannelRules.span(channel(161, .ghz5, 80)))
        #expect(ChannelRules.overlaps(channel(153, .ghz5, 80), channel(149, .ghz5)))
        #expect(!ChannelRules.overlaps(channel(153, .ghz5, 80), channel(165, .ghz5)))
        #expect(ChannelRules.overlaps(channel(36, .ghz5, 80), channel(48, .ghz5)))
        #expect(!ChannelRules.overlaps(channel(36, .ghz5, 80), channel(52, .ghz5)))
        #expect(ChannelRules.overlaps(channel(128, .ghz5, 160), channel(100, .ghz5)), "100–128")
        #expect(ChannelRules.span(channel(44, .ghz5, 40)) == 5210...5250, "44–48")
        #expect(ChannelRules.overlaps(channel(5, .ghz6, 80), channel(13, .ghz6)), "6 GHz 1–13")
        #expect(!ChannelRules.overlaps(channel(5, .ghz6, 80), channel(17, .ghz6)))
        #expect(!ChannelRules.overlaps(channel(36, .ghz5), channel(36, .ghz6)), "bands never share air")
    }

    @Test func theMeasuredScanIsClear() {
        let advice = ChannelRules.advice(networks: measuredScan, current: channel(153, .ghz5, 80))
        #expect(advice.verdict == "clear" && advice.overlapping == 0)
        #expect(advice.advice == "channel 153 (5 GHz, 80 MHz) overlaps no other network")
        let six = advice.loads.first { $0.band == .ghz2 && $0.channel == 6 }
        #expect(six?.networks == 3 && six?.strong == 1, "the networks on 2 and 5, and the 40 MHz one on 11, reach 6")
        #expect(advice.loads.contains { $0.band == .ghz5 && $0.channel == 128 })
    }

    @Test func aCrowdedChannelGetsASuggestion() {
        var networks = measuredScan.filter { $0.channel.band != .ghz2 }
        for (number, rssi) in [(6, -48), (6, -60), (7, -65), (4, -80), (8, -82), (11, -88)] {
            networks.append(NearbyNetwork(ssid: nil, bssid: nil, rssi: rssi, channel: channel(number, .ghz2), security: nil))
        }
        let advice = ChannelRules.advice(networks: networks, current: channel(6, .ghz2))
        #expect(advice.overlapping == 4, "the Mac's own access point (loudest on 6) is not counted")
        #expect(advice.strongOverlapping == 2)
        #expect(advice.verdict == "crowded")
        #expect(advice.advice.contains("; channel 1 has 1 —"), "\(advice.advice)")
    }

    @Test func notConnectedStillAdvises() {
        let advice = ChannelRules.advice(networks: measuredScan, current: nil)
        #expect(advice.verdict == "unknown" && advice.current == nil)
        #expect(advice.advice.hasPrefix("not connected"))
    }

    @Test func coreWLANValuesInWords() {
        #expect(WiFiNames.phyMode(6) == "802.11ax" && WiFiNames.phyMode(7) == "802.11be" && WiFiNames.phyMode(99) == nil)
        #expect(WiFiNames.generation(6, band: .ghz5) == "Wi-Fi 6" && WiFiNames.generation(6, band: .ghz6) == "Wi-Fi 6E")
        #expect(WiFiNames.security(4) == "WPA2 Personal" && WiFiNames.security(11) == "WPA3 Personal")
        #expect(WiFiNames.security(Int.max) == nil, "kCWSecurityUnknown")
        #expect(WiFiNames.band(3) == .ghz6 && WiFiNames.band(0) == .unknown)
        #expect(WiFiNames.width(3) == 80 && WiFiNames.width(0) == nil)
        #expect(WiFiNames.strongestFirst.count == 16 && Set(WiFiNames.strongestFirst).count == 16)
    }
}
