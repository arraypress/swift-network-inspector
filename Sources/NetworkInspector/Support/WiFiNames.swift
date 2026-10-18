//
//  WiFiNames.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  CoreWLAN's enumerations in words, by their raw values as the macOS 27
//  SDK's CoreWLANTypes.h defines them, so a value added later reads as
//  unknown rather than as a wrong name.
//

import Foundation

enum WiFiNames {

    /// CWPHYMode → the 802.11 amendment.
    static func phyMode(_ raw: Int) -> String? {
        switch raw {
        case 1: "802.11a"
        case 2: "802.11b"
        case 3: "802.11g"
        case 4: "802.11n"
        case 5: "802.11ac"
        case 6: "802.11ax"
        case 7: "802.11be"
        default: nil
        }
    }

    /// CWPHYMode → the Wi-Fi Alliance's generation name; 802.11ax on 6 GHz is Wi-Fi 6E.
    static func generation(_ raw: Int, band: WiFiBand?) -> String? {
        switch raw {
        case 4: "Wi-Fi 4"
        case 5: "Wi-Fi 5"
        case 6: band == .ghz6 ? "Wi-Fi 6E" : "Wi-Fi 6"
        case 7: "Wi-Fi 7"
        default: nil
        }
    }

    /// CWSecurity → words; nil for none-reported and unknown.
    static func security(_ raw: Int) -> String? {
        switch raw {
        case 0: "none"
        case 1: "WEP"
        case 2: "WPA Personal"
        case 3: "WPA/WPA2 Personal"
        case 4: "WPA2 Personal"
        case 5: "Personal"
        case 6: "Dynamic WEP"
        case 7: "WPA Enterprise"
        case 8: "WPA/WPA2 Enterprise"
        case 9: "WPA2 Enterprise"
        case 10: "Enterprise"
        case 11: "WPA3 Personal"
        case 12: "WPA3 Enterprise"
        case 13: "WPA2/WPA3 Personal"
        case 14: "OWE"
        case 15: "OWE transition"
        default: nil
        }
    }

    /// CWSecurity raw values, strongest first: what a scan checks a network for.
    static let strongestFirst = [12, 11, 13, 9, 4, 10, 5, 14, 15, 8, 3, 7, 2, 6, 1, 0]

    /// CWChannelBand → band.
    static func band(_ raw: Int) -> WiFiBand {
        switch raw {
        case 1: .ghz2
        case 2: .ghz5
        case 3: .ghz6
        default: .unknown
        }
    }

    /// CWChannelWidth → MHz.
    static func width(_ raw: Int) -> Int? {
        switch raw {
        case 1: 20
        case 2: 40
        case 3: 80
        case 4: 160
        default: nil
        }
    }
}
