//
//  Array+CString.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension Array where Element == CChar {

    /// The UTF-8 text up to the first NUL, as a C function filled it.
    var cString: String {
        String(decoding: prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
