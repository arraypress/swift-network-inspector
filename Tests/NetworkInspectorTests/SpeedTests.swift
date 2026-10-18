//
//  SpeedTests.swift
//  NetworkInspectorTests
//
//  Created by David Sherlock on 2026.
//
//  networkQuality's JSON from three real runs on a VPN: a default
//  (parallel) run, a sequential one capped at 10 s, and one pointed at a
//  configuration file that does not exist — which exits 0.
//

import Foundation
import Testing
@testable import NetworkInspector

struct SpeedTests {

    @Test func aParallelRun() throws {
        let result = try SpeedJSON.result(try Fixture.data("networkquality-parallel.json"))
        #expect(result.downloadBitsPerSecond == 438_273_024 && result.uploadBitsPerSecond == 71_986_272)
        #expect(abs((result.responsiveness ?? 0) - 162.1011199951172) < 1e-9)
        #expect(result.rating == .low && !result.sequential)
        #expect(result.downloadResponsiveness == nil && result.uploadResponsiveness == nil)
        #expect(abs((result.idleLatencyMs ?? 0) - 246.7164764404297) < 1e-9)
        #expect(abs((result.loadedLatencyMs ?? 0) - 60_000 / 162.1011199951172) < 1e-9)
        #expect(result.interface == "utun6" && result.server == "example-edge-bx-024.aaplimg.com")
        #expect(result.downloadBytes == 592_457_950 && result.uploadBytes == 122_814_462)
        #expect(abs((result.seconds ?? 0) - 19.744) < 0.0005, "22:32:36.336 → 22:32:56.080")
    }

    @Test func aSequentialRunRatesItsWorseDirection() throws {
        let result = try SpeedJSON.result(try Fixture.data("networkquality-sequential.json"))
        #expect(result.sequential && result.responsiveness == nil)
        #expect(abs((result.downloadResponsiveness ?? 0) - 137.83349609375) < 1e-9)
        #expect(abs((result.uploadResponsiveness ?? 0) - 147.86451721191406) < 1e-9)
        #expect(abs((result.loadedLatencyMs ?? 0) - 60_000 / 137.83349609375) < 1e-9, "the lower score")
        #expect(result.rating == .low)
    }

    @Test func aFailedRunExitsZeroAndIsStillAnError() throws {
        #expect(throws: NetworkInspectorError.speedTestFailed(domain: "NSURLErrorDomain", code: -1100)) {
            try SpeedJSON.result(try Fixture.data("networkquality-error.json"))
        }
        #expect(throws: NetworkInspectorError.unreadableOutput(tool: "networkQuality", reason: "not a JSON object")) {
            try SpeedJSON.result(Data("Downlink: 400 Mbps".utf8))
        }
        let missing = try SpeedJSON.result(Data(#"{"dl_throughput": 1000, "ul_throughput": true}"#.utf8))
        #expect(missing.downloadBitsPerSecond == 1000 && missing.uploadBitsPerSecond == nil, "a boolean is not a number")
        #expect(missing.rating == nil && missing.loadedLatencyMs == nil && missing.seconds == nil)
    }

    @Test func networkQualitysOwnThresholds() {
        // Measured from +[NetworkQualityResult ratingForResponsivenessScore:] on macOS 27.0.1.
        #expect(ResponsivenessRules.rating(0) == .low)
        #expect(ResponsivenessRules.rating(200) == .low)
        #expect(ResponsivenessRules.rating(200.9) == .low, "the framework takes whole RPM")
        #expect(ResponsivenessRules.rating(201) == .medium)
        #expect(ResponsivenessRules.rating(1000) == .medium)
        #expect(ResponsivenessRules.rating(1001) == .high)
    }

    @Test func theCommandLine() {
        #expect(SpeedTest.arguments(SpeedOptions()) == ["-c"])
        #expect(SpeedTest.arguments(SpeedOptions(sequential: true)) == ["-c", "-s"])
        #expect(SpeedTest.arguments(SpeedOptions(upload: false)) == ["-c", "-u"], "-u implies -s")
        #expect(SpeedTest.arguments(SpeedOptions(sequential: true, download: false)) == ["-c", "-d"])
        #expect(SpeedTest.arguments(SpeedOptions(interface: "en0")) == ["-c", "-I", "en0"])
    }

    @Test func anInterfaceThatDoesNotExistIsRefusedBeforeTheRun() {
        // networkQuality itself waits for ever on one, without a word.
        #expect(throws: NetworkInspectorError.noSuchInterface("nosuch0")) {
            try SpeedTest.run(SpeedOptions(interface: "nosuch0"))
        }
    }
}
