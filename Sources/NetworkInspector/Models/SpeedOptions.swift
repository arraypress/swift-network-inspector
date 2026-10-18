//
//  SpeedOptions.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// How to run networkQuality.
public struct SpeedOptions: Codable, Sendable, Equatable {

    /// Download then upload, one at a time (`-s`), instead of both at once.
    /// Gives a responsiveness score per direction.
    public var sequential: Bool

    /// Measure download.
    public var download: Bool

    /// Measure upload.
    public var upload: Bool

    /// Bind the test to this interface (`-I`), e.g. `en0`.
    public var interface: String?

    /// Stop networkQuality after this many seconds. It can hang with no
    /// output (measured: an interface that does not exist, past 160 s).
    public var timeout: Double

    public init(sequential: Bool = false, download: Bool = true, upload: Bool = true, interface: String? = nil,
                timeout: Double = 90) {
        self.sequential = sequential
        self.download = download
        self.upload = upload
        self.interface = interface
        self.timeout = timeout
    }
}
