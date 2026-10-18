//
//  Route.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  The way out, from SystemConfiguration's dynamic store — the primary
//  interface and router (`State:/Network/Global/IPv4`) and the resolvers
//  (`State:/Network/Global/DNS`) — plus any VPN tunnel. With a VPN the
//  store can still name en0 as primary while traffic leaves through the
//  tunnel (measured: networkQuality ran on utun6 with en0 primary).
//

import Foundation
import SystemConfiguration

public enum Route {

    /// The route as it stands.
    public static func current() -> RouteInfo {
        let store = SCDynamicStoreCreate(nil, "NetworkInspector" as CFString, nil, nil)
        func value(_ key: String) -> [String: Any]? {
            guard let store else { return nil }
            return SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any]
        }
        let ipv4 = value("State:/Network/Global/IPv4")
        let dns = value("State:/Network/Global/DNS")
        return RouteInfo(primaryInterface: ipv4?["PrimaryInterface"] as? String,
                         router: ipv4?["Router"] as? String,
                         dnsServers: dns?["ServerAddresses"] as? [String] ?? [],
                         tunnels: Interfaces.tunnels(Interfaces.addresses()))
    }
}
