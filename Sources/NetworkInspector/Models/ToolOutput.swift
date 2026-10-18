//
//  ToolOutput.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a system tool left behind.
struct ToolOutput: Equatable, Sendable {
    let status: Int32
    let timedOut: Bool
    let stdout: Data
    let stderr: Data

    var text: String { String(decoding: stdout, as: UTF8.self) }
    var errorText: String { String(decoding: stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
}
