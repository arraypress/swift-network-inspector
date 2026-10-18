//
//  SystemTests.swift
//  NetworkInspectorTests
//
//  Created by David Sherlock on 2026.
//
//  The firewall's sentences, app bundles from paths, and — on this Mac,
//  with nothing leaving it — a listener and loopback traffic the test
//  makes itself, found again through netstat and nettop.
//

import Darwin
import Foundation
import Testing
@testable import NetworkInspector

struct SystemTests {

    @Test func firewallSentences() {
        #expect(FirewallText.enabled("Firewall is enabled. (State = 1)") == true)
        #expect(FirewallText.enabled("Firewall is enabled. (State = 2)") == true, "essential services only")
        #expect(FirewallText.enabled("Firewall is disabled. (State = 0)") == false)
        #expect(FirewallText.enabled("something else") == nil)
        #expect(FirewallText.stealth("Firewall stealth mode is on") == true)
        #expect(FirewallText.stealth("Firewall stealth mode is off") == false)
        #expect(FirewallText.blockAll("Firewall has block all state set to disabled.") == false)
        #expect(FirewallText.blockAll("Firewall has block all state set to enabled.") == true)
    }

    @Test func theOutermostAppIsTheAppAPersonKnows() {
        let helper = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/155.0.8059.85/Helpers/Google Chrome Helper (Aperitif).app/Contents/MacOS/Google Chrome Helper (Aperitif)"
        #expect(AppBundles.outermostApp(helper) == "/Applications/Google Chrome.app")
        #expect(AppBundles.outermostApp("/Applications/Dropbox.app/Contents/PlugIns/DropboxFileProvider.appex/Contents/MacOS/DropboxFileProvider") == "/Applications/Dropbox.app")
        #expect(AppBundles.outermostApp("/Applications/Mullvad VPN.app/Contents/Resources/mullvad-daemon") == "/Applications/Mullvad VPN.app")
        #expect(AppBundles.outermostApp("/usr/libexec/remoted") == nil)
        #expect(AppBundles.outermostApp("/Users/me/My.app.backup/tool") == nil, "only a component ending in .app")
    }

    @Test func rootsProcessesAreNamedWithoutRoot() {
        let launchd = ProcessLookup.identity(pid: 1)
        #expect(launchd.path == "/sbin/launchd" && launchd.name == "launchd")
        #expect(launchd.user == "root" && launchd.uid == 0)
        let gone = ProcessLookup.identity(pid: 99_999_999, fallbackName: "Google Chrome H")
        #expect(gone.path == nil && gone.name == "Google Chrome H")
        #expect(ProcessLookup.identity(pid: 99_999_999).name == "pid 99999999")
        let me = ProcessLookup.identity(pid: getpid())
        #expect(me.uid == getuid() && me.path != nil)
    }

    @Test func otherUsersProcessesAreCounted() throws {
        let others = try #require(ProcessLookup.otherUsersProcessCount())
        #expect(others >= 1, "launchd, at least, is root's")
    }

    @Test func aLoopbackListenerIsFoundAndCalledLoopback() throws {
        let listener = try LoopbackListener()
        defer { listener.close() }
        let report = try Ports.report(port: listener.port)
        #expect(report.complete && report.source != .lsof, "\(report.source): \(report.notes)")
        let row = try #require(report.ports.first { $0.proto == .tcp })
        #expect(row.address == "127.0.0.1" && row.reach == .loopback && !row.reach.isExposed)
        #expect(row.process?.pid == getpid())
    }

    @Test func loopbackTrafficShowsUpWhenAskedFor() throws {
        // Two seconds of nettop while this process streams to itself, from
        // before nettop starts until after it stops.
        let listener = try LoopbackListener()
        defer { listener.close() }
        let sender = Thread { listener.sendToSelf(bytes: 30_000_000, pause: 0.005) }
        sender.start()
        let report = try Bandwidth.measure(seconds: 2, includeLoopback: true)
        let mine = report.processes.filter { $0.process.pid == getpid() }
        let moved = mine.reduce(Int64(0)) { $0 + $1.bytesIn }
        #expect(moved >= 1_000_000, "about 6 MB a second was sent: \(report.processes.prefix(5).map { "\($0.process.name) \($0.bytesIn)" })")
        #expect(report.seconds > 1.5 && report.seconds < 2.5)
        #expect(report.includesLoopback)
    }
}

/// A TCP listener on 127.0.0.1 on a free port, and a way to send it bytes.
final class LoopbackListener: @unchecked Sendable {

    let descriptor: Int32
    let port: Int

    init() throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_port = 0
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(fd, 4) == 0 else { Darwin.close(fd); throw POSIXError(.EADDRINUSE) }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        descriptor = fd
        port = Int(UInt16(bigEndian: address.sin_port))
    }

    /// Connects, accepts, and pushes `bytes` through the pair, 64 KB at a
    /// time with `pause` seconds between.
    func sendToSelf(bytes: Int, pause: Double) {
        let client = socket(AF_INET, SOCK_STREAM, 0)
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_port = UInt16(port).bigEndian
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(client, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard connected == 0 else { Darwin.close(client); return }
        let server = accept(descriptor, nil, nil)
        let reader = Thread {
            var buffer = [UInt8](repeating: 0, count: 65_536)
            while read(server, &buffer, buffer.count) > 0 {}
            Darwin.close(server)
        }
        reader.start()
        let chunk = [UInt8](repeating: 0x42, count: 65_536)
        var sent = 0
        while sent < bytes {
            let count = write(client, chunk, min(chunk.count, bytes - sent))
            if count <= 0 { break }
            sent += count
            Thread.sleep(forTimeInterval: pause)
        }
        Darwin.close(client)
    }

    func close() { Darwin.close(descriptor) }
}
