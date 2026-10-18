//
//  SocketTests.swift
//  NetworkInspectorTests
//
//  Created by David Sherlock on 2026.
//
//  netstat and lsof on real captures, the address forms each writes, who
//  can reach a socket, and the merge into rows. Counts were worked out
//  from the fixtures separately, in Python.
//

import Foundation
import Testing
@testable import NetworkInspector

struct SocketTests {

    func netstat() throws -> [SocketEntry] {
        let tcp = try #require(NetstatText.sockets(try Fixture.text("netstat-tcp.txt")))
        let udp = try #require(NetstatText.sockets(try Fixture.text("netstat-udp.txt")))
        return tcp + udp
    }

    @Test func netstatReadsEverySocket() throws {
        let tcp = try #require(NetstatText.sockets(try Fixture.text("netstat-tcp.txt")))
        let udp = try #require(NetstatText.sockets(try Fixture.text("netstat-udp.txt")))
        #expect(tcp.count == 85 && udp.count == 92)
        #expect(tcp.filter(\.isListening).count == 13)
        #expect(Set(tcp.compactMap(\.state)) == ["LISTEN", "ESTABLISHED", "CLOSE_WAIT", "FIN_WAIT_1", "LAST_ACK"])
        #expect(udp.allSatisfy { $0.state == nil }, "UDP rows leave the state column empty")
    }

    @Test func processNamesWithSpacesAndNoName() throws {
        let sockets = try netstat()
        let chrome = try #require(sockets.first { $0.pid == 2149 })
        #expect(chrome.processName == "Google Chrome He", "netstat's 16-character name, spaces and all")
        let orphan = try #require(sockets.first { $0.pid == 71051 })
        #expect(orphan.processName == nil, "`:71051` — the process exited and its name went with it")
        #expect(orphan.state == "FIN_WAIT_1")
        #expect(!sockets.contains { $0.pid == nil }, "every row in this capture carries a pid")
    }

    @Test func netstatAddressesInEveryForm() throws {
        let sockets = try netstat()
        let remoted = try #require(sockets.first { $0.local.port == 49936 })
        #expect(remoted.local.address == "fe80::1%anri0" && remoted.family == "6", "-l keeps IPv6 whole, zone included")
        #expect(remoted.processName == "remoted" && remoted.pid == 569)
        let dropbox = try #require(sockets.first { $0.local.port == 17603 })
        #expect(dropbox.local.address == "127.0.0.1" && dropbox.remote == nil)
        let connected = try #require(sockets.first { $0.local.address == "2001:db8::1" && $0.proto == .tcp })
        #expect(connected.remote?.address.hasPrefix("2001:db8::") == true && connected.remote?.port == 443)
        #expect(sockets.contains { $0.family == "46" && $0.local.address == "*" }, "dual-stack udp46 rows")
        #expect(EndpointText.netstat("*.*") == Endpoint(address: "*", port: nil))
        #expect(EndpointText.netstat("*.5353") == Endpoint(address: "*", port: 5353))
        #expect(EndpointText.netstat("::1.8080") == Endpoint(address: "::1", port: 8080))
        #expect(EndpointText.netstat("192.0.2.4.x") == nil)
        #expect(EndpointText.netstat("nodot") == nil)
    }

    @Test func aNetstatWithoutThePIDColumnIsRefused() {
        let old = """
            Active Internet connections (including servers)
            Proto Recv-Q Send-Q  Local Address          Foreign Address        (state)
            tcp4       0      0  *.22                   *.*                    LISTEN
            """
        #expect(NetstatText.sockets(old) == nil, "no process:pid column → the caller falls back to lsof")
        #expect(NetstatText.sockets("") == nil)
    }

    @Test func lsofListsOnlyWhatItCanSee() throws {
        let tcp = LsofText.sockets(try Fixture.text("lsof-tcp-listen.txt"))
        #expect(tcp.count == 11 && tcp.allSatisfy(\.isListening))
        #expect(!tcp.contains { $0.pid == 569 }, "root's remoted is invisible to lsof without root")
        let udp = LsofText.sockets(try Fixture.text("lsof-udp.txt"))
        #expect(udp.count == 58)
        let v6 = try #require(udp.first { $0.local.address == "fe80::7" })
        #expect(v6.local.port == 63211 && v6.remote == Endpoint(address: "fe80::8", port: 60318) && v6.family == "6")
        #expect(udp.contains { $0.local == Endpoint(address: "*", port: nil) && $0.remote == nil }, "`*:*`")
    }

    @Test func netstatSeesEveryListenerLsofSees() throws {
        // Captured seconds apart on the same Mac: each lsof listener is in
        // netstat's list, and netstat has root's that lsof could not see.
        let lsof = Set(LsofText.sockets(try Fixture.text("lsof-tcp-listen.txt")).map { "\($0.local.port ?? 0)/\($0.pid ?? 0)" })
        let netstat = Set(try netstat().filter { $0.proto == .tcp && $0.isListening }.map { "\($0.local.port ?? 0)/\($0.pid ?? 0)" })
        #expect(lsof.isSubset(of: netstat))
        #expect(netstat.subtracting(lsof) == ["49935/569", "49936/569"])
    }

    @Test func lsofRowsInEveryForm() {
        let row = #"Python\x20web 4242 me 5u IPv6 0xabc 0t0 TCP [::1]:8000 (LISTEN)"#
        let socket = LsofText.socket(Substring(row))
        #expect(socket?.processName == "Python web" && socket?.pid == 4242)
        #expect(socket?.local == Endpoint(address: "::1", port: 8000) && socket?.state == "LISTEN")
        #expect(LsofText.socket("COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME") == nil)
        #expect(LsofText.socket("node 1 me 3u IPv4 0x1 0t0 TCP") == nil, "no NAME column")
        #expect(EndpointText.lsof("[fe80::1%en0]:5353") == Endpoint(address: "fe80::1%en0", port: 5353))
        #expect(EndpointText.lsof("[::1]8000") == nil)
        #expect(EndpointText.lsof("*:*") == Endpoint(address: "*", port: nil))
    }

    @Test func reachIsDecidedByTheBoundAddress() {
        for wildcard in ["*", "0.0.0.0", "::"] { #expect(ReachRules.reach(of: wildcard) == .all) }
        for loopback in ["127.0.0.1", "127.148.92.153", "::1", "::ffff:127.0.0.1"] {
            #expect(ReachRules.reach(of: loopback) == .loopback, "\(loopback)")
        }
        #expect(ReachRules.reach(of: "fe80::1%anri0") == .linkLocal)
        #expect(ReachRules.reach(of: "169.254.10.1") == .linkLocal)
        #expect(ReachRules.reach(of: "192.0.2.4") == .address)
        #expect(ReachRules.reach(of: "2001:db8::1") == .address)
        #expect(!Reach.loopback.isExposed && Reach.linkLocal.isExposed && Reach.all.isExposed)
        #expect(ReachRules.interface(of: "fe80::1%anri0", addresses: [:]) == "anri0")
        #expect(ReachRules.interface(of: "192.0.2.4", addresses: ["192.0.2.4": "en0"]) == "en0")
    }

    @Test func listenersMergeAcrossFamiliesAndSockets() throws {
        let rows = PortMerge.rows(try netstat(), includeConnected: false, port: nil, addresses: [:]) {
            ProcessIdentity(pid: $0, name: $1 ?? "?")
        }
        let tcp = rows.filter { $0.proto == .tcp }
        #expect(tcp.count == 10 && rows.filter { $0.proto == .udp }.count == 19)
        #expect(tcp.filter(\.reach.isExposed).count == 7 && tcp.filter { $0.reach == .loopback }.count == 3)
        let airplay = try #require(tcp.first { $0.port == 7000 })
        #expect(airplay.families == ["4", "6"] && airplay.sockets == 2 && airplay.reach == .all)
        #expect(airplay.process?.name == "ControlCenter")
        let mdns = try #require(rows.first { $0.proto == .udp && $0.port == 5353 && $0.process?.pid == 1402 })
        #expect(mdns.sockets == 7, "Spotify's seven mDNS sockets are one row")
        #expect(rows.map(\.port) == rows.map(\.port).sorted())
    }

    @Test func oneQuestionOnePort() throws {
        let rows = PortMerge.rows(try netstat(), includeConnected: false, port: 17500, addresses: [:]) {
            ProcessIdentity(pid: $0, name: $1 ?? "?")
        }
        #expect(rows.count == 2 && Set(rows.map(\.proto)) == [.tcp, .udp])
        #expect(rows.allSatisfy { $0.process?.pid == 1505 })
        let none = PortMerge.rows(try netstat(), includeConnected: false, port: 3000, addresses: [:]) { _, _ in nil }
        #expect(none.isEmpty)
    }

    @Test func allAddsConnectedSocketsOneRowEach() throws {
        let sockets = try netstat()
        let rows = PortMerge.rows(sockets, includeConnected: true, port: nil, addresses: ["192.0.2.1": "en0"]) { _, _ in nil }
        let established = rows.filter { $0.state == "ESTABLISHED" }
        #expect(established.count == sockets.filter { $0.state == "ESTABLISHED" }.count)
        #expect(established.allSatisfy { $0.remote != nil && $0.sockets == 1 })
        #expect(rows.first { $0.address == "192.0.2.1" }?.interface == "en0")
    }

    @Test func nettopListsEveryUsersSockets() throws {
        let blocks = NettopCSV.blocks(try Fixture.text("nettop-sockets.csv"))
        let block = try #require(blocks.first)
        let sockets = NettopSockets.sockets(header: block.header, lines: block.lines)
        #expect(sockets.count == 158)
        #expect(sockets.filter { $0.proto == .tcp }.count == 82 && sockets.filter { $0.proto == .udp }.count == 76)
        #expect(sockets.filter(\.isListening).filter { $0.proto == .tcp }.count == 13)
        let remoted = try #require(sockets.first { $0.local.port == 49935 })
        #expect(remoted.pid == 569 && remoted.processName == "remoted" && remoted.state == "LISTEN")
        #expect(remoted.local.address == "fe80::1%anri0", "IPv6 joins the port with a dot")
        let chrome = try #require(sockets.first { $0.pid == 2149 })
        #expect(chrome.processName == "Google Chrome H" && chrome.state == "ESTABLISHED")
        #expect(chrome.local.address == "192.0.2.1" && chrome.remote?.port == 443, "IPv4 joins it with a colon")
        #expect(sockets.contains { $0.proto == .udp && $0.local == Endpoint(address: "*", port: nil) && $0.remote == nil })
        let rows = PortMerge.rows(sockets, includeConnected: false, port: nil, addresses: [:]) { ProcessIdentity(pid: $0, name: $1 ?? "?") }
        #expect(rows.filter { $0.proto == .tcp }.count == 10 && rows.filter { $0.proto == .udp }.count == 15)
    }

    @Test func nettopRowsInEveryForm() {
        let owner = (name: "Foo, Bar", pid: Int32(7))
        let v4 = NettopSockets.socket("tcp4 *:8080<->*:*", owner: owner)
        #expect(v4?.local == Endpoint(address: "*", port: 8080) && v4?.remote == nil && v4?.pid == 7)
        #expect(NettopSockets.socket("udp6 ::1.53<->::1.60000", owner: nil)?.remote == Endpoint(address: "::1", port: 60000))
        #expect(NettopSockets.socket("Mail.4810", owner: nil) == nil, "a process row")
        #expect(NettopSockets.socket("tcp4 nonsense", owner: nil) == nil)
        #expect(NettopSockets.state("FinWait1") == "FIN_WAIT_1" && NettopSockets.state("Listen") == "LISTEN")
        #expect(NettopSockets.state("SynSent") == "SYN_SENT" && NettopSockets.state("") == nil)
        let lines = ["Foo, Bar.7,,", "tcp4 127.0.0.1:9000<->*:*,Listen,"]
        let sockets = NettopSockets.sockets(header: ",state,", lines: lines)
        #expect(sockets.count == 1 && sockets[0].processName == "Foo, Bar" && sockets[0].pid == 7, "a comma in a process name")
        #expect(sockets[0].state == "LISTEN")
    }

    @Test func lsofFillsInWhatNettopSkipped() {
        let shared = SocketEntry(proto: .udp, family: "4", local: Endpoint(address: "*", port: 5353), remote: nil,
                                 state: nil, pid: 9, processName: "a")
        let dualStack = SocketEntry(proto: .udp, family: "6", local: Endpoint(address: "*", port: 5353), remote: nil,
                                    state: nil, pid: 9, processName: "a")
        let idle = SocketEntry(proto: .udp, family: "4", local: Endpoint(address: "*", port: 59825), remote: nil,
                               state: nil, pid: 9, processName: "a")
        let merged = Ports.merged([shared], [dualStack, idle])
        #expect(merged == [shared, idle], "the same socket named by another family is not counted twice")
    }
}
