//
//  SpeedResult.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What networkQuality measured.
public struct SpeedResult: Codable, Sendable, Equatable {

    /// Download throughput, bits per second; nil when not measured.
    public let downloadBitsPerSecond: Double?

    /// Upload throughput, bits per second; nil when not measured.
    public let uploadBitsPerSecond: Double?

    /// Round trips per minute under load, both directions at once (the
    /// default, parallel run).
    public let responsiveness: Double?

    /// Round trips per minute while downloading (sequential runs).
    public let downloadResponsiveness: Double?

    /// Round trips per minute while uploading (sequential runs).
    public let uploadResponsiveness: Double?

    /// networkQuality's own rating of the responsiveness given — the
    /// parallel score, else the lower of the two directions.
    public let rating: ResponsivenessRating?

    /// Idle latency, milliseconds (`base_rtt`).
    public let idleLatencyMs: Double?

    /// The round trip under load implied by the responsiveness score:
    /// 60,000 ms divided by the round trips per minute.
    public let loadedLatencyMs: Double?

    /// The interface the test ran on.
    public let interface: String?

    /// The server measured against.
    public let server: String?

    /// Bytes downloaded during the test.
    public let downloadBytes: Int64?

    /// Bytes uploaded during the test.
    public let uploadBytes: Int64?

    /// When it started and ended, as networkQuality wrote them (local time).
    public let start: String?
    public let end: String?

    /// How long the run took, seconds.
    public let seconds: Double?

    /// Whether the directions ran one after the other.
    public let sequential: Bool

    public init(downloadBitsPerSecond: Double?, uploadBitsPerSecond: Double?, responsiveness: Double?,
                downloadResponsiveness: Double?, uploadResponsiveness: Double?, rating: ResponsivenessRating?,
                idleLatencyMs: Double?, loadedLatencyMs: Double?, interface: String?, server: String?,
                downloadBytes: Int64?, uploadBytes: Int64?, start: String?, end: String?, seconds: Double?,
                sequential: Bool) {
        self.downloadBitsPerSecond = downloadBitsPerSecond
        self.uploadBitsPerSecond = uploadBitsPerSecond
        self.responsiveness = responsiveness
        self.downloadResponsiveness = downloadResponsiveness
        self.uploadResponsiveness = uploadResponsiveness
        self.rating = rating
        self.idleLatencyMs = idleLatencyMs
        self.loadedLatencyMs = loadedLatencyMs
        self.interface = interface
        self.server = server
        self.downloadBytes = downloadBytes
        self.uploadBytes = uploadBytes
        self.start = start
        self.end = end
        self.seconds = seconds
        self.sequential = sequential
    }
}
