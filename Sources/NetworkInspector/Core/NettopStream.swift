//
//  NettopStream.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  nettop on a pseudo-terminal, sample by sample. On a pipe nettop buffers
//  everything until it exits, and after its last sample it takes about
//  4.5 s more to exit (measured: a two-sample, one-second run took 5.0 s
//  where the samples arrived at 0 and 1 s). On a terminal each line comes
//  as it is written, so a sample can be used the moment it is complete and
//  nettop stopped — SIGTERM ends it at once.
//
//  Every sample starts with a header line, which begins with a comma or
//  `time,` (a data row begins with a timestamp's digits or a name). A
//  sample is complete when the next header arrives, when the stream has
//  been quiet for `quiet` seconds after its rows, or when nettop exits.
//

import Darwin
import Foundation

/// One sample's lines, as nettop wrote them.
struct NettopBlock: Equatable, Sendable {
    let header: String
    var lines: [String]
    let receivedAt: Date
}

enum NettopStream {

    /// How long a pause after a sample's rows means the sample is complete.
    static let quiet = 0.35

    /// Whether a line starts a sample.
    static func isHeader(_ line: String) -> Bool { line.hasPrefix(",") || line.hasPrefix("time,") }

    /// Runs nettop with `arguments` and hands each complete sample to
    /// `body` until it returns false, nettop exits, or `timeout` passes
    /// (nil: no limit, for a watch stopped by the caller).
    ///
    /// - Throws: ``NetworkInspectorError/toolFailed(tool:reason:)`` when it
    ///   cannot start or prints nothing usable;
    ///   ``NetworkInspectorError/timedOut(tool:seconds:)``.
    static func run(_ arguments: [String], timeout: Double?, _ body: (NettopBlock) -> Bool) throws {
        var primary: Int32 = -1, secondary: Int32 = -1
        guard openpty(&primary, &secondary, nil, nil, nil) == 0 else {
            throw NetworkInspectorError.toolFailed(tool: "nettop", reason: "no pseudo-terminal: errno \(errno)")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = arguments
        process.standardOutput = FileHandle(fileDescriptor: secondary, closeOnDealloc: false)
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch {
            close(primary)
            close(secondary)
            throw NetworkInspectorError.toolFailed(tool: "nettop", reason: error.localizedDescription)
        }
        close(secondary)
        defer {
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
            close(primary)
        }

        let deadline = timeout.map { Date().addingTimeInterval($0) }
        var pending = Data()
        var current: NettopBlock?
        var lastLine = Date.distantPast
        var delivered = 0
        var buffer = [UInt8](repeating: 0, count: 65_536)

        /// Hands over the sample being read; false once `body` has had enough.
        func finish() -> Bool {
            guard let block = current, !block.lines.isEmpty else { current = nil; return true }
            current = nil
            delivered += 1
            return body(block)
        }

        while true {
            if let deadline, let timeout, Date() > deadline {
                throw NetworkInspectorError.timedOut(tool: "nettop", seconds: timeout)
            }
            var poller = pollfd(fd: primary, events: Int16(POLLIN), revents: 0)
            let ready = poll(&poller, 1, 50)
            if ready < 0 && errno == EINTR { continue }
            if ready > 0 {
                let count = read(primary, &buffer, buffer.count)
                if count <= 0 { break }   // nettop exited: the terminal reads EOF or EIO
                pending.append(contentsOf: buffer[0..<count])
                while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
                    let line = String(decoding: pending[pending.startIndex..<newline], as: UTF8.self)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\r "))
                    pending.removeSubrange(pending.startIndex...newline)
                    guard !line.isEmpty else { continue }
                    if isHeader(line) {
                        guard finish() else { return }
                        current = NettopBlock(header: line, lines: [], receivedAt: Date())
                    } else if current != nil {
                        current?.lines.append(line)
                        lastLine = Date()
                    }
                }
            } else if current?.lines.isEmpty == false, Date().timeIntervalSince(lastLine) >= quiet {
                guard finish() else { return }
            }
        }
        guard finish() else { return }
        if delivered == 0 {
            throw NetworkInspectorError.toolFailed(tool: "nettop", reason: "it printed no samples")
        }
    }
}
