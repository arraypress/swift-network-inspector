//
//  FirewallText.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  socketfilterfw's sentences as booleans:
//  `Firewall is enabled. (State = 1)`, `Firewall stealth mode is off`,
//  `Firewall has block all state set to disabled.` State 2 means enabled
//  with essential services only, still enabled.
//

import Foundation

enum FirewallText {

    /// `--getglobalstate`.
    static func enabled(_ text: String) -> Bool? {
        if let match = text.firstMatch(of: /State = (\d+)/), let state = Int(match.1) { return state > 0 }
        if text.contains("is enabled") { return true }
        if text.contains("is disabled") { return false }
        return nil
    }

    /// `--getstealthmode`.
    static func stealth(_ text: String) -> Bool? {
        if text.contains("mode is on") { return true }
        if text.contains("mode is off") { return false }
        return nil
    }

    /// `--getblockall`.
    static func blockAll(_ text: String) -> Bool? {
        if text.contains("set to enabled") { return true }
        if text.contains("set to disabled") { return false }
        return nil
    }
}
