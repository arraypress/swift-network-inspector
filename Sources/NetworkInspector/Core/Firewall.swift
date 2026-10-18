//
//  Firewall.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  The application firewall's state, from socketfilterfw, which answers
//  these three questions without root (13 ms each, measured).
//

import Foundation

public enum Firewall {

    static let tool = "/usr/libexec/ApplicationFirewall/socketfilterfw"

    /// The current state; a question that cannot be answered is nil.
    public static func current() -> FirewallState {
        func ask(_ flag: String) -> String? {
            guard let output = try? ToolRunner.run(tool, [flag], timeout: 10), output.status == 0 else { return nil }
            return output.text
        }
        return FirewallState(enabled: ask("--getglobalstate").flatMap(FirewallText.enabled),
                             stealth: ask("--getstealthmode").flatMap(FirewallText.stealth),
                             blockAll: ask("--getblockall").flatMap(FirewallText.blockAll))
    }
}
