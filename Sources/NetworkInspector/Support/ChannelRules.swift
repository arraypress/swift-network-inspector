//
//  ChannelRules.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  Which channels share air. CoreWLAN reports a network's primary 20 MHz
//  channel and its width; the frequencies it actually occupies follow from
//  the band plan:
//
//  - 2.4 GHz channels are 5 MHz apart and 22 MHz wide (the 802.11b mask),
//    so neighbours within four channels overlap — 1, 6 and 11 are the
//    three that do not.
//    A 40 MHz network's second half may sit above or below; both are
//    assumed.
//  - 5 GHz wide channels are fixed blocks: 40 MHz pairs (36–40, 44–48…),
//    80 MHz quads (36–48, 52–64, 100–112, 116–128, 132–144, 149–161) and
//    160 MHz octets (36–64, 100–128, 149–177). Blocks are counted from 36,
//    and from 149 for the upper band.
//  - 6 GHz blocks are counted the same way from channel 1.
//
//  Two networks interfere when their spans overlap in the same band.
//  "Strong" is -70 dBm or louder: loud enough that the radios take turns.
//

import Foundation

enum ChannelRules {

    /// A network this loud or louder counts as strong.
    static let strongRSSI = -70

    /// The frequencies a channel occupies, in MHz.
    static func span(_ channel: WiFiChannel) -> ClosedRange<Int> {
        let width = channel.widthMHz ?? 20
        let n = channel.number
        switch channel.band {
        case .ghz2:
            let centre = n == 14 ? 2484 : 2407 + 5 * n
            // 22 MHz, the 802.11b mask: channels 1 and 5 overlap, 1 and 6 do not.
            return width >= 40 ? (centre - 31)...(centre + 31) : (centre - 11)...(centre + 11)
        case .ghz5:
            return block(n, width: width, origin: n >= 149 ? 149 : 36, base: 5000)
        case .ghz6:
            return block(n, width: width, origin: 1, base: 5950)
        case .unknown:
            return 0...0
        }
    }

    /// A fixed-block channel's frequencies: the block starting at `origin`
    /// plus whole multiples of the width, in 5 MHz channel numbers.
    private static func block(_ n: Int, width: Int, origin: Int, base: Int) -> ClosedRange<Int> {
        let step = max(4, width / 5)
        let first = n < origin ? n : origin + ((n - origin) / step) * step
        let last = first + step - 4
        return (base + 5 * first - 10)...(base + 5 * last + 10)
    }

    /// Whether two channels share any frequencies.
    static func overlaps(_ a: WiFiChannel, _ b: WiFiChannel) -> Bool {
        guard a.band == b.band, a.band != .unknown else { return false }
        let x = span(a), y = span(b)
        return x.lowerBound < y.upperBound && y.lowerBound < x.upperBound
    }

    /// The advice for a scan, given the channel this Mac uses.
    static func advice(networks: [NearbyNetwork], current: WiFiChannel?) -> ChannelAdvice {
        // The Mac's own access point is, almost always, the loudest network
        // on exactly its channel; without BSSIDs that is the best tell.
        var others = networks
        if let current, let own = networks.indices
            .filter({ networks[$0].channel.number == current.number && networks[$0].channel.band == current.band })
            .max(by: { networks[$0].rssi < networks[$1].rssi }) {
            others.remove(at: own)
        }
        let loads = loads(others, heard: networks)
        guard let current else {
            let quiet = quietest(loads, band: .ghz2)
            return ChannelAdvice(current: nil, overlapping: 0, strongOverlapping: 0, verdict: "unknown",
                                 advice: "not connected" + (quiet.map { "; the quietest 2.4 GHz channel here is \($0.channel)" } ?? ""),
                                 loads: loads)
        }
        let sharing = others.filter { overlaps($0.channel, current) }
        let strong = sharing.filter { $0.rssi >= strongRSSI }.count
        let verdict = strong >= 2 || sharing.count >= 5 ? "crowded" : (strong == 0 && sharing.count <= 1) ? "clear" : "busy"
        var sentence = "channel \(current.number) (\(current.band.rawValue)"
            + (current.widthMHz.map { ", \($0) MHz" } ?? "") + ") overlaps "
            + (sharing.isEmpty ? "no other network" : "\(sharing.count) other network\(sharing.count == 1 ? "" : "s")")
            + (strong > 0 ? ", \(strong) of them strong" : "")
        if verdict != "clear" {
            if current.band == .ghz2 {
                if let quiet = quietest(loads, band: .ghz2), quiet.channel != current.number,
                   quiet.networks < sharing.count {
                    sentence += "; channel \(quiet.channel) has \(quiet.networks) — or use 5 GHz if the router offers it"
                } else {
                    sentence += "; 5 GHz would be quieter if the router offers it"
                }
            } else if let quiet = quietest(loads, band: current.band), quiet.networks < sharing.count {
                sentence += "; channel \(quiet.channel) has \(quiet.networks) here"
            }
        }
        return ChannelAdvice(current: current, overlapping: sharing.count, strongOverlapping: strong,
                             verdict: verdict, advice: sentence, loads: loads)
    }

    /// The load on 1, 6 and 11, and on every 5 and 6 GHz channel heard,
    /// each taken as a 20 MHz channel.
    static func loads(_ others: [NearbyNetwork], heard: [NearbyNetwork]) -> [ChannelLoad] {
        var channels = [1, 6, 11].map { WiFiChannel(number: $0, band: .ghz2, widthMHz: 20) }
        let upper = Set(heard.filter { $0.channel.band != .ghz2 && $0.channel.band != .unknown }
            .map { WiFiChannel(number: $0.channel.number, band: $0.channel.band, widthMHz: 20) })
        channels += upper.sorted { ($0.band.rawValue, $0.number) < ($1.band.rawValue, $1.number) }
        return channels.map { channel in
            let sharing = others.filter { overlaps($0.channel, channel) }
            return ChannelLoad(band: channel.band, channel: channel.number, networks: sharing.count,
                               strong: sharing.filter { $0.rssi >= strongRSSI }.count)
        }
    }

    /// The least loaded channel in a band: fewest strong, then fewest in all, then lowest number.
    static func quietest(_ loads: [ChannelLoad], band: WiFiBand) -> ChannelLoad? {
        loads.filter { $0.band == band }.min { ($0.strong, $0.networks, $0.channel) < ($1.strong, $1.networks, $1.channel) }
    }
}
