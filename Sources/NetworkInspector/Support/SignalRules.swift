//
//  SignalRules.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  A verdict from signal and noise. These are the common rules of thumb
//  for Wi-Fi design, not measurements of this library's: -67 dBm is the
//  usual target for calls and video, below -75 dBm links slow and drop,
//  and a signal-to-noise ratio under 15 dB leaves little for the radio to
//  work with. The verdict is the worse of the two.
//

import Foundation

enum SignalRules {

    /// The verdict for a signal and, when measured, its noise floor.
    /// CoreWLAN reports noise 0 for networks it did not measure; that is
    /// treated as unknown.
    static func quality(rssi: Int, noise: Int?) -> SignalQuality {
        let bySignal: SignalQuality = rssi >= -50 ? .excellent : rssi >= -67 ? .good : rssi >= -75 ? .fair : .poor
        guard let snr = snr(rssi: rssi, noise: noise) else { return bySignal }
        let byNoise: SignalQuality = snr >= 40 ? .excellent : snr >= 25 ? .good : snr >= 15 ? .fair : .poor
        return rank(bySignal) >= rank(byNoise) ? bySignal : byNoise
    }

    /// Signal minus noise, or nil when the noise was not measured.
    static func snr(rssi: Int, noise: Int?) -> Int? {
        guard let noise, noise < 0 else { return nil }
        return rssi - noise
    }

    /// Higher is worse, so the worse verdict wins a comparison.
    private static func rank(_ quality: SignalQuality) -> Int {
        switch quality {
        case .excellent: 0
        case .good: 1
        case .fair: 2
        case .poor: 3
        }
    }
}
