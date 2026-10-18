//
//  NettopTests.swift
//  NetworkInspectorTests
//
//  Created by David Sherlock on 2026.
//
//  nettop's CSV on real captures — three column layouts — and the rows a
//  capture never showed: names with dots and commas, short and broken
//  rows. Expected values were worked out from the fixture separately, in
//  Python, not by running this parser.
//

import Foundation
import Testing
@testable import NetworkInspector

struct NettopTests {

    @Test func aTwoSampleCaptureReadsAsTwoSamples() throws {
        let samples = NettopCSV.samples(try Fixture.text("nettop-time.csv"))
        #expect(samples.map(\.rows.count) == [27, 27])
        let claude = try #require(samples[1].rows[5091])
        #expect(claude.name == "2.1.302", "the pid is after the LAST dot: Claude Code's binary is named 2.1.302")
        #expect(claude.bytesIn == 86344 && claude.bytesOut == 6807989)
        #expect(samples[1].rows[2149]?.name == "Google Chrome H", "nettop cuts names to 15 characters")
        // The first row's timestamp is the sample's.
        let first: Double = 22 * 3600 + 28 * 60 + 51.593773
        #expect(samples[0].time == first)
    }

    @Test func columnsAreFoundByNameNotPosition() throws {
        // Without the time column, and with nettop's full default set.
        #expect(NettopCSV.samples(try Fixture.text("nettop-bytes.csv")).map(\.rows.count) == [26, 26])
        let full = NettopCSV.samples(try Fixture.text("nettop-default.csv"))
        #expect(full.map(\.rows.count) == [27])
        #expect(full[0].rows[591] == NettopRow(name: "apsd", pid: 591, bytesIn: 5529, bytesOut: 11659))
        let layout = try #require(NettopCSV.layout(header: "time,,interface,state,bytes_in,bytes_out,rx_dupe,"))
        #expect(layout.name == 1 && layout.time == 0 && layout.bytesIn == 4 && layout.bytesOut == 5)
        #expect(NettopCSV.layout(header: "22:28:51.5,apsd.591,5529,11659,") == nil, "a data row is not a header")
    }

    @Test func namesWithDotsAndCommasKeepTheirPID() throws {
        let layout = try #require(NettopCSV.layout(header: "time,,bytes_in,bytes_out,"))
        let commas = try #require(NettopCSV.row("10:00:00.5,Foo, Bar.v2.99,1,2,", layout: layout))
        #expect(commas.row == NettopRow(name: "Foo, Bar.v2", pid: 99, bytesIn: 1, bytesOut: 2))
        #expect(commas.time == 36000.5)
        let dots = try #require(NettopCSV.row("10:00:00.5,com.apple.x.y.123,5,6,", layout: layout))
        #expect(dots.row.name == "com.apple.x.y" && dots.row.pid == 123)
        #expect(NettopCSV.namePID("no-pid-here") == nil)
        #expect(NettopCSV.namePID("trailing.") == nil)
        #expect(NettopCSV.namePID(".42")?.1 == 42, "an empty name still has a pid")
    }

    @Test func brokenRowsAreSkippedNotGuessed() throws {
        let layout = try #require(NettopCSV.layout(header: "time,,bytes_in,bytes_out,"))
        #expect(NettopCSV.row("10:00:00.5,proc.1,7,", layout: layout) == nil, "a field missing")
        #expect(NettopCSV.row("10:00:00.5,proc.1,,8,", layout: layout) == nil, "an empty count")
        #expect(NettopCSV.row("10:00:00.5,proc.1,7 KiB,8,", layout: layout) == nil, "a human-readable count")
        let text = "time,,bytes_in,bytes_out,\n10:00:00.0,a.1,5,5,\ngarbage\n10:00:00.0,b.2,1,1,\n"
        #expect(NettopCSV.samples(text).first?.rows.count == 2)
        #expect(NettopCSV.samples("a.1,5,5,\n").isEmpty, "rows before any header belong to no sample")
    }

    @Test func ratesComeFromTheDifferenceBetweenSamples() throws {
        let samples = NettopCSV.samples(try Fixture.text("nettop-time.csv"))
        let report = TrafficMath.report(before: samples[0], after: samples[1], nominal: 1, includesLoopback: false,
                                        endedAt: Date(timeIntervalSince1970: 0), identify: Fixture.identity)
        #expect(abs(report.seconds - 0.999525) < 1e-6, "the window is nettop's own clock, not the nominal second")
        #expect(report.processes.map(\.process.pid) == [844, 5091, 2149, 699, 1402])
        let top = report.processes[0]
        #expect(top.bytesIn == 1409289 && top.bytesOut == 1479111)
        let rate: Double = 1_409_289 / 0.999525
        #expect(abs(top.inPerSecond - rate) < 0.01)
        #expect(report.bytesIn == 1808659 && report.bytesOut == 1945984)
        #expect(!report.processes.contains { $0.bytesIn == 0 && $0.bytesOut == 0 }, "idle processes are left out")
    }

    @Test func newExitedAndReusedPIDs() {
        let before = NettopSample(time: 10, rows: [
            1: NettopRow(name: "steady", pid: 1, bytesIn: 100, bytesOut: 100),
            2: NettopRow(name: "gone", pid: 2, bytesIn: 500, bytesOut: 500),
            3: NettopRow(name: "old", pid: 3, bytesIn: 9000, bytesOut: 9000),
        ])
        let after = NettopSample(time: 12, rows: [
            1: NettopRow(name: "steady", pid: 1, bytesIn: 150, bytesOut: 100),
            3: NettopRow(name: "new", pid: 3, bytesIn: 40, bytesOut: 9050),
            4: NettopRow(name: "fresh", pid: 4, bytesIn: 70, bytesOut: 0),
        ])
        let rows = Dictionary(uniqueKeysWithValues: TrafficMath.deltas(from: before, to: after).map { ($0.pid, $0) })
        #expect(rows[1]?.bytesIn == 50 && rows[1]?.bytesOut == 0)
        #expect(rows[2] == nil, "an exited process's last bytes are lost, not negative")
        #expect(rows[3]?.bytesIn == 40, "a counter that went down is a reused pid, counted from zero")
        #expect(rows[3]?.bytesOut == 50, "the other direction still grew, so it is a plain difference")
        #expect(rows[4]?.bytesIn == 70, "a pid first seen in the window counts from zero")
    }

    @Test func theWindowSurvivesMidnightAndMissingClocks() {
        let late = NettopSample(time: 86_399.5), early = NettopSample(time: 0.5)
        #expect(TrafficMath.elapsed(from: late, to: early, nominal: 5) == 1, "a wrap, not the nominal fallback")
        let start = Date(timeIntervalSince1970: 100)
        let clocked = TrafficMath.elapsed(from: NettopSample(receivedAt: start),
                                          to: NettopSample(receivedAt: start.addingTimeInterval(2.5)), nominal: 1)
        #expect(clocked == 2.5)
        #expect(TrafficMath.elapsed(from: NettopSample(), to: NettopSample(), nominal: 3) == 3)
    }

    @Test func helpersCountAsTheirApp() {
        let chrome = "/Applications/Google Chrome.app"
        func traffic(_ pid: Int32, _ name: String, path: String?, app: String?, _ bytes: Int64) -> ProcessTraffic {
            ProcessTraffic(process: ProcessIdentity(pid: pid, name: name, path: path, appName: app == nil ? nil : "Google Chrome",
                                                    bundleIdentifier: app == nil ? nil : "com.google.Chrome", appPath: app),
                           bytesIn: bytes, bytesOut: 0, inPerSecond: Double(bytes), outPerSecond: 0)
        }
        let apps = TrafficMath.apps([
            traffic(10, "Google Chrome", path: chrome + "/Contents/MacOS/Google Chrome", app: chrome, 100),
            traffic(11, "Google Chrome Helper", path: chrome + "/Contents/Frameworks/x/Helper.app/Contents/MacOS/h", app: chrome, 400),
            traffic(20, "curl", path: "/usr/bin/curl", app: nil, 300),
            traffic(21, "curl", path: "/usr/bin/curl", app: nil, 50),
            traffic(30, "gone", path: nil, app: nil, 1),
        ], seconds: 2)
        #expect(apps.map(\.name) == ["Google Chrome", "curl", "gone"])
        #expect(apps[0].pids == [10, 11] && apps[0].bytesIn == 500 && apps[0].inPerSecond == 250)
        #expect(apps[0].bundleIdentifier == "com.google.Chrome")
        #expect(apps[1].pids == [20, 21], "processes outside an app group by executable")
    }

    @Test func theCommandLineCountsOnlyRealInterfacesByDefault() {
        #expect(Bandwidth.arguments(seconds: 2, includeLoopback: false)
                == ["-P", "-L", "0", "-x", "-s", "2", "-J", "time,bytes_in,bytes_out", "-t", "external"])
        #expect(!Bandwidth.arguments(seconds: 1, includeLoopback: true).contains("-t"))
    }
}
