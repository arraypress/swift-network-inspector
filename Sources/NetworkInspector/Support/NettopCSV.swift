//
//  NettopCSV.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  `nettop -P -L <n> -x -J time,bytes_in,bytes_out` as values. Each sample
//  starts with a header line (`time,,bytes_in,bytes_out,`); each row is
//  `<time>,<name>.<pid>,<in>,<out>,`. Nothing is quoted, so:
//
//  - a process name may hold dots (`2.1.302.5091` is the process `2.1.302`,
//    pid 5091 — Claude Code's binary is named after its version), so the
//    pid is the part after the LAST dot;
//  - a name may hold commas, so the name column takes every field the row
//    has beyond the header's count, and the columns after it shift along.
//
//  Columns are found by name in the header, because nettop's help warns
//  that the order of -J columns may change.
//

import Foundation

enum NettopCSV {

    /// Where each column sits, from a header line.
    struct Layout: Equatable {
        /// Fields in a header line, the empty one after the trailing comma included.
        let count: Int
        /// The process column: the one with an empty name.
        let name: Int
        let time: Int?
        let bytesIn: Int
        let bytesOut: Int
    }

    /// The layout a header line describes, or nil when it is not a header.
    static func layout(header line: Substring) -> Layout? {
        let fields = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
        guard let bytesIn = fields.firstIndex(of: "bytes_in"), let bytesOut = fields.firstIndex(of: "bytes_out"),
              let name = fields.firstIndex(of: ""), name < bytesIn else { return nil }
        return Layout(count: fields.count, name: name, time: fields.firstIndex(of: "time"),
                      bytesIn: bytesIn, bytesOut: bytesOut)
    }

    /// One data row, or nil for a row that does not fit the layout.
    static func row(_ line: Substring, layout: Layout) -> (row: NettopRow, time: Double?)? {
        let fields = line.split(separator: ",", omittingEmptySubsequences: false)
        let extra = fields.count - layout.count
        guard extra >= 0 else { return nil }
        // Fields after the name column move right by the commas the name held.
        func at(_ index: Int) -> Substring? {
            let shifted = index > layout.name ? index + extra : index
            return shifted < fields.count ? fields[shifted] : nil
        }
        let label = fields[layout.name...(layout.name + extra)].joined(separator: ",")
        guard let (name, pid) = namePID(label),
              let inText = at(layout.bytesIn), let bytesIn = Int64(inText),
              let outText = at(layout.bytesOut), let bytesOut = Int64(outText) else { return nil }
        let time = layout.time.flatMap { at($0) }.flatMap { secondsOfDay(String($0)) }
        return (NettopRow(name: name, pid: pid, bytesIn: bytesIn, bytesOut: bytesOut), time)
    }

    /// `Google Chrome H.2149` → (`Google Chrome H`, 2149); the pid follows the last dot.
    static func namePID(_ label: String) -> (String, Int32)? {
        guard let dot = label.lastIndex(of: "."), let pid = Int32(label[label.index(after: dot)...]), pid >= 0 else {
            return nil
        }
        return (String(label[..<dot]), pid)
    }

    /// `22:28:51.593791` → seconds since midnight.
    static func secondsOfDay(_ text: String) -> Double? {
        let parts = text.split(separator: ":")
        guard parts.count == 3, let hours = Double(parts[0]), let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }

    /// One sample from its header and rows; rows that do not fit are skipped.
    static func sample(header: String, lines: [String], receivedAt: Date? = nil) -> NettopSample {
        var sample = NettopSample(receivedAt: receivedAt)
        guard let layout = layout(header: Substring(header)) else { return sample }
        for line in lines {
            guard let parsed = row(Substring(line), layout: layout) else { continue }
            sample.rows[parsed.row.pid] = parsed.row
            if sample.time == nil { sample.time = parsed.time }
        }
        return sample
    }

    /// Every sample in a whole capture, in order.
    static func samples(_ text: String) -> [NettopSample] {
        blocks(text).map { sample(header: $0.header, lines: $0.lines) }
    }

    /// A whole capture cut into samples, as the stream cuts it live.
    static func blocks(_ text: String) -> [NettopBlock] {
        var blocks: [NettopBlock] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if NettopStream.isHeader(line) {
                blocks.append(NettopBlock(header: line, lines: [], receivedAt: Date(timeIntervalSince1970: 0)))
            } else if !blocks.isEmpty {
                blocks[blocks.count - 1].lines.append(line)
            }
        }
        return blocks
    }
}
