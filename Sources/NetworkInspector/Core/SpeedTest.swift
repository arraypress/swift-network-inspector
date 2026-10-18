//
//  SpeedTest.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  macOS's own speed test, `networkQuality -c`, as a value. It uses real
//  bandwidth — measured here: 19.8 s and 715 MB for a default run, 26.8 s
//  and 1.15 GB for another — and it can hang without a word when bound to
//  an interface that does not exist, so the interface is checked first
//  and the run is stopped after `timeout`.
//

import Foundation

public enum SpeedTest {

    /// Runs the test.
    ///
    /// - Throws: ``NetworkInspectorError/noSuchInterface(_:)``,
    ///   ``NetworkInspectorError/timedOut(tool:seconds:)``,
    ///   ``NetworkInspectorError/speedTestFailed(domain:code:)``,
    ///   ``NetworkInspectorError/unreadableOutput(tool:reason:)``.
    public static func run(_ options: SpeedOptions = SpeedOptions()) throws -> SpeedResult {
        try check(options)
        let output = try ToolRunner.run("/usr/bin/networkQuality", arguments(options), timeout: options.timeout)
        if output.timedOut { throw NetworkInspectorError.timedOut(tool: "networkQuality", seconds: options.timeout) }
        guard !output.stdout.isEmpty else {
            throw NetworkInspectorError.toolFailed(tool: "networkQuality",
                                                   reason: output.errorText.isEmpty ? "exit \(output.status), no output" : output.errorText)
        }
        return try SpeedJSON.result(output.stdout)
    }

    /// Refuses what would make networkQuality hang: an interface that does
    /// not exist. Cheap; a caller can run it before saying a test is starting.
    ///
    /// - Throws: ``NetworkInspectorError/noSuchInterface(_:)``.
    public static func check(_ options: SpeedOptions) throws {
        if let name = options.interface, !Interfaces.exists(name) {
            throw NetworkInspectorError.noSuchInterface(name)
        }
    }

    /// The command line: JSON (`-c`); `-s` for sequential; `-u` skips the
    /// upload and `-d` the download (each implies `-s`); `-I` binds.
    static func arguments(_ options: SpeedOptions) -> [String] {
        var arguments = ["-c"]
        if options.sequential && options.download && options.upload { arguments.append("-s") }
        if !options.upload { arguments.append("-u") }
        if !options.download { arguments.append("-d") }
        if let interface = options.interface { arguments += ["-I", interface] }
        return arguments
    }
}
