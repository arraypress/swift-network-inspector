//
//  AppBundles.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  The app an executable belongs to, by its path. Helpers, extensions and
//  daemons live inside the app that ships them —
//  `Google Chrome.app/…/Google Chrome Helper (Aperitif).app/…`,
//  `Dropbox.app/Contents/PlugIns/DropboxFileProvider.appex/…`,
//  `Mullvad VPN.app/Contents/Resources/mullvad-daemon` — so the OUTERMOST
//  .app is the app a person knows. NSRunningApplication answers nil for
//  every one of those (measured), so the path is the only route.
//

import Foundation

enum AppBundles {

    /// The outermost `.app` folder in a path, or nil when there is none.
    static func outermostApp(_ path: String) -> String? {
        var built = ""
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            built += "/" + component
            if component.hasSuffix(".app") { return built }
        }
        return nil
    }
}
