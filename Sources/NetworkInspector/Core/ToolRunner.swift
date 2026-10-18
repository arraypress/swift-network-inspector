//
//  ToolRunner.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  Running a system tool with no shell and no pipe to deadlock on: its
//  output goes to temporary files, read once it has exited; its stdin is
//  /dev/null so nothing it runs can wait on a person; and it is stopped
//  after a timeout, because networkQuality, given an interface that does
//  not exist, waits for ever without printing a word.
//

import Foundation

enum ToolRunner {

    /// Runs `executable` with `arguments`, stopping it after `timeout` seconds.
    ///
    /// - Throws: ``NetworkInspectorError/toolFailed(tool:reason:)`` when it cannot be started.
    static func run(_ executable: String, _ arguments: [String], timeout: Double) throws -> ToolOutput {
        let tool = (executable as NSString).lastPathComponent
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("network-inspector-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        } catch {
            throw NetworkInspectorError.toolFailed(tool: tool, reason: error.localizedDescription)
        }
        defer { try? FileManager.default.removeItem(at: scratch) }
        let outURL = scratch.appendingPathComponent("out"), errURL = scratch.appendingPathComponent("err")
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        FileManager.default.createFile(atPath: errURL.path, contents: nil)
        guard let out = try? FileHandle(forWritingTo: outURL), let err = try? FileHandle(forWritingTo: errURL) else {
            throw NetworkInspectorError.toolFailed(tool: tool, reason: "no scratch files")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        do { try process.run() } catch {
            throw NetworkInspectorError.toolFailed(tool: tool, reason: error.localizedDescription)
        }
        var timedOut = false
        if done.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            process.terminate()
            if done.wait(timeout: .now() + 3) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                done.wait()
            }
        }
        try? out.close()
        try? err.close()
        return ToolOutput(status: process.terminationStatus, timedOut: timedOut,
                          stdout: (try? Data(contentsOf: outURL)) ?? Data(),
                          stderr: (try? Data(contentsOf: errURL)) ?? Data())
    }
}
