//
//  ProcessLookup.swift
//  NetworkInspector
//
//  Created by David Sherlock on 2026.
//
//  A pid to a name, path, user and app — without root. Measured on
//  macOS 27 as an ordinary user: `proc_pidpath` and the `kern.proc.pid`
//  sysctl answer for every process, root's included (`remoted`,
//  `mDNSResponder`, a VPN daemon); `proc_name` and `proc_pidinfo` refuse
//  other users' processes with EPERM, so they are not used.
//

import Darwin
import Foundation

public enum ProcessLookup {

    /// Who `pid` is. `fallbackName` — the cut name a tool printed — is used
    /// when the path cannot be read (the process has exited).
    public static func identity(pid: Int32, fallbackName: String? = nil) -> ProcessIdentity {
        let path = executablePath(pid)
        let uid = owner(pid)
        let app = path.flatMap(app(containing:))
        return ProcessIdentity(pid: pid,
                               name: path.map { ($0 as NSString).lastPathComponent } ?? fallbackName ?? "pid \(pid)",
                               path: path, user: uid.flatMap(userName), uid: uid,
                               appName: app?.name, bundleIdentifier: app?.bundleIdentifier, appPath: app?.path)
    }

    /// The executable's path, from the kernel.
    static func executablePath(_ pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return buffer.cString
    }

    /// The owning user's id, from `kern.proc.pid`.
    static func owner(_ pid: Int32) -> UInt32? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ucred.cr_uid
    }

    /// How many running processes belong to a user other than this one,
    /// from `kern.proc.all` — which any user may read.
    public static func otherUsersProcessCount() -> Int? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return nil }
        let stride = MemoryLayout<kinfo_proc>.stride
        var processes = [kinfo_proc](repeating: kinfo_proc(), count: size / stride + 16)
        size = processes.count * stride
        guard sysctl(&mib, UInt32(mib.count), &processes, &size, nil, 0) == 0 else { return nil }
        let me = getuid()
        return processes.prefix(size / stride).filter { $0.kp_eproc.e_ucred.cr_uid != me }.count
    }

    /// A login name.
    static func userName(_ uid: UInt32) -> String? {
        guard let entry = getpwuid(uid) else { return nil }
        return String(cString: entry.pointee.pw_name)
    }

    /// The app an executable sits in, with its display name and bundle id.
    static func app(containing executable: String) -> (name: String, bundleIdentifier: String?, path: String)? {
        guard let appPath = AppBundles.outermostApp(executable) else { return nil }
        let bundle = Bundle(path: appPath)
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
        return (name, bundle?.bundleIdentifier, appPath)
    }
}
