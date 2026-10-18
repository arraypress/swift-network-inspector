//
//  Interfaces.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  The addresses on this Mac's interfaces, from getifaddrs: which
//  interface a listener's specific address belongs to, and which tunnels
//  carry a routable address. (`mac net` lists the interfaces themselves.)
//

import Darwin
import Foundation

enum Interfaces {

    /// One address on one interface.
    struct Address: Equatable {
        let interface: String
        let address: String
        let ipv4: Bool
        let up: Bool
    }

    /// Every address on every interface.
    static func addresses() -> [Address] {
        var found: [Address] = []
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            guard let socket = entry.pointee.ifa_addr else { continue }
            let family = socket.pointee.sa_family
            guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(socket, socklen_t(socket.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let flags = Int32(entry.pointee.ifa_flags)
            found.append(Address(interface: String(cString: entry.pointee.ifa_name),
                                 address: host.cString.split(separator: "%").first.map(String.init) ?? "",
                                 ipv4: family == UInt8(AF_INET),
                                 up: flags & IFF_UP != 0 && flags & IFF_RUNNING != 0))
        }
        return found
    }

    /// Address → interface, for naming a listener's interface.
    static func byAddress(_ addresses: [Address]) -> [String: String] {
        var map: [String: String] = [:]
        for entry in addresses where map[entry.address] == nil { map[entry.address] = entry.interface }
        return map
    }

    /// Tunnel interfaces (`utun`, `ipsec`, `ppp`) that are up with an IPv4
    /// address outside 169.254/16. macOS keeps several utun interfaces with
    /// only link-local IPv6 for its own services; a VPN gives one an address.
    static func tunnels(_ addresses: [Address]) -> [String] {
        let names = addresses.filter { entry in
            entry.up && entry.ipv4 && !entry.address.hasPrefix("169.254.")
                && ["utun", "ipsec", "ppp"].contains { entry.interface.hasPrefix($0) }
        }.map(\.interface)
        return Array(Set(names)).sorted()
    }

    /// Whether an interface of that name exists.
    static func exists(_ name: String) -> Bool { if_nametoindex(name) != 0 }
}
